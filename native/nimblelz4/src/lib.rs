extern crate lz4_flex;
extern crate rustler;

use rustler::types::atom;
use rustler::types::binary::{Binary, OwnedBinary};
use rustler::{Encoder, Env, Error, Resource, ResourceArc, Term};
use std::io::{Read, Write};
use std::sync::mpsc::{self, Receiver, Sender, TryRecvError};
use std::sync::Mutex;

#[rustler::nif(schedule = "DirtyCpu")]
fn compress<'a>(env: Env<'a>, iolist_to_compress: Term<'a>) -> Result<Term<'a>, Error> {
    let binary_to_compress: Binary = Binary::from_iolist(iolist_to_compress).unwrap();
    let compressed_slice = lz4_flex::block::compress(binary_to_compress.as_slice());

    Ok(binary_from_slice(env, &compressed_slice).encode(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn compress_frame<'a>(env: Env<'a>, iolist_to_compress: Term<'a>) -> Result<Term<'a>, Error> {
    let binary_to_compress: Binary = Binary::from_iolist(iolist_to_compress).unwrap();

    let mut compressor = lz4_flex::frame::FrameEncoder::new(Vec::new());
    std::io::Write::write(&mut compressor, binary_to_compress.as_slice()).unwrap();
    let compressed = compressor.finish().unwrap();

    Ok(binary_from_slice(env, &compressed).encode(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn decompress<'a>(
    env: Env<'a>,
    binary_to_decompress: Binary,
    uncompressed_size: usize,
) -> Result<Term<'a>, Error> {
    match lz4_flex::block::decompress(binary_to_decompress.as_slice(), uncompressed_size) {
        Ok(decompressed_vec) => {
            Ok((atom::ok(), binary_from_slice(env, &decompressed_vec)).encode(env))
        }
        Err(decompress_err) => Ok((atom::error(), decompress_err.to_string()).encode(env)),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn decompress_frame<'a>(env: Env<'a>, binary_to_decompress: Binary) -> Result<Term<'a>, Error> {
    let mut decompressed_buf: Vec<u8> = Vec::new();
    let mut decompressor = lz4_flex::frame::FrameDecoder::new(binary_to_decompress.as_slice());

    match decompressor.read_to_end(&mut decompressed_buf) {
        Ok(_) => Ok((atom::ok(), binary_from_slice(env, &decompressed_buf)).encode(env)),
        Err(e) => Ok((atom::error(), e.to_string()).encode(env)),
    }
}

// ---------------------------------------------------------------------------
// Streaming compression (LZ4 frame format)
// ---------------------------------------------------------------------------
//
// A `FrameEncoder` writing into an in-memory `Vec<u8>` is held alive in a NIF
// resource. Each `compress_stream_update` call writes a chunk into the encoder
// and drains whatever complete compressed blocks the encoder has produced so
// far. `compress_stream_finish` flushes the remaining buffered data and the
// frame's end marker. This keeps memory usage bounded by a single block,
// regardless of the total size of the stream.

struct CompressStream {
    encoder: Mutex<Option<lz4_flex::frame::FrameEncoder<Vec<u8>>>>,
}

#[rustler::resource_impl]
impl Resource for CompressStream {}

#[rustler::nif]
fn compress_stream_new() -> ResourceArc<CompressStream> {
    ResourceArc::new(CompressStream {
        encoder: Mutex::new(Some(lz4_flex::frame::FrameEncoder::new(Vec::new()))),
    })
}

#[rustler::nif(schedule = "DirtyCpu")]
fn compress_stream_update<'a>(
    env: Env<'a>,
    resource: ResourceArc<CompressStream>,
    iodata: Term<'a>,
) -> Result<Term<'a>, Error> {
    let data: Binary = Binary::from_iolist(iodata)?;

    let mut guard = resource.encoder.lock().unwrap();
    let encoder = guard
        .as_mut()
        .ok_or_else(|| Error::RaiseTerm(Box::new("stream already finished")))?;

    encoder
        .write_all(data.as_slice())
        .map_err(|e| Error::Term(Box::new(e.to_string())))?;

    let drained = std::mem::take(encoder.get_mut());
    Ok(binary_from_slice(env, &drained).encode(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn compress_stream_finish<'a>(
    env: Env<'a>,
    resource: ResourceArc<CompressStream>,
) -> Result<Term<'a>, Error> {
    let mut guard = resource.encoder.lock().unwrap();
    let encoder = guard
        .take()
        .ok_or_else(|| Error::RaiseTerm(Box::new("stream already finished")))?;

    let final_bytes = encoder
        .finish()
        .map_err(|e| Error::Term(Box::new(e.to_string())))?;

    Ok(binary_from_slice(env, &final_bytes).encode(env))
}

// ---------------------------------------------------------------------------
// Streaming decompression (LZ4 frame format)
// ---------------------------------------------------------------------------
//
// `lz4_flex`'s `FrameDecoder` is pull-based (it reads from an `io::Read`) and
// uses `read_exact` internally, so it cannot be fed partial blocks and resumed.
// To turn it into a push-based API we run the decoder on a dedicated thread
// that reads compressed bytes from a channel and writes decompressed chunks
// back to another channel. `decompress_stream_update` feeds compressed bytes
// and drains any decompressed output that is ready; `decompress_stream_finish`
// closes the input (signalling EOF) and blocks until the thread has flushed
// everything. Output that is not ready during an `update` (because the decoder
// is waiting for the rest of a block) is delivered by a later `update` or by
// `finish` — the concatenation of all returned chunks is the full plaintext.

enum DecompressMsg {
    Chunk(Vec<u8>),
    Error(String),
}

struct DecompressStream {
    input: Mutex<Option<Sender<Vec<u8>>>>,
    output: Mutex<Receiver<DecompressMsg>>,
}

#[rustler::resource_impl]
impl Resource for DecompressStream {}

/// `io::Read` backed by a channel of compressed chunks. Blocks waiting for more
/// input so the `FrameDecoder`'s `read_exact` calls can always be satisfied, and
/// reports EOF once the sending side is dropped.
struct ChannelReader {
    rx: Receiver<Vec<u8>>,
    buf: Vec<u8>,
    pos: usize,
}

impl Read for ChannelReader {
    fn read(&mut self, out: &mut [u8]) -> std::io::Result<usize> {
        while self.pos >= self.buf.len() {
            match self.rx.recv() {
                Ok(chunk) => {
                    self.buf = chunk;
                    self.pos = 0;
                }
                // Sender dropped: no more input is coming, signal EOF.
                Err(_) => return Ok(0),
            }
        }

        let n = std::cmp::min(out.len(), self.buf.len() - self.pos);
        out[..n].copy_from_slice(&self.buf[self.pos..self.pos + n]);
        self.pos += n;
        Ok(n)
    }
}

#[rustler::nif]
fn decompress_stream_new() -> ResourceArc<DecompressStream> {
    let (input_tx, input_rx) = mpsc::channel::<Vec<u8>>();
    let (output_tx, output_rx) = mpsc::channel::<DecompressMsg>();

    std::thread::spawn(move || {
        let reader = ChannelReader {
            rx: input_rx,
            buf: Vec::new(),
            pos: 0,
        };
        let mut decoder = lz4_flex::frame::FrameDecoder::new(reader);
        let mut buf = vec![0u8; 64 * 1024];

        loop {
            match decoder.read(&mut buf) {
                Ok(0) => break,
                Ok(n) => {
                    if output_tx
                        .send(DecompressMsg::Chunk(buf[..n].to_vec()))
                        .is_err()
                    {
                        // Receiver dropped (resource gone): stop working.
                        break;
                    }
                }
                Err(e) => {
                    let _ = output_tx.send(DecompressMsg::Error(e.to_string()));
                    break;
                }
            }
        }
    });

    ResourceArc::new(DecompressStream {
        input: Mutex::new(Some(input_tx)),
        output: Mutex::new(output_rx),
    })
}

#[rustler::nif(schedule = "DirtyCpu")]
fn decompress_stream_update<'a>(
    env: Env<'a>,
    resource: ResourceArc<DecompressStream>,
    iodata: Term<'a>,
) -> Result<Term<'a>, Error> {
    let data: Binary = Binary::from_iolist(iodata)?;

    {
        let guard = resource.input.lock().unwrap();
        match guard.as_ref() {
            Some(tx) => {
                let _ = tx.send(data.as_slice().to_vec());
            }
            None => return Ok((atom::error(), "stream already finished").encode(env)),
        }
    }

    // Drain whatever output is ready without blocking.
    let output = resource.output.lock().unwrap();
    let mut collected: Vec<u8> = Vec::new();
    loop {
        match output.try_recv() {
            Ok(DecompressMsg::Chunk(chunk)) => collected.extend_from_slice(&chunk),
            Ok(DecompressMsg::Error(e)) => return Ok((atom::error(), e).encode(env)),
            Err(TryRecvError::Empty) | Err(TryRecvError::Disconnected) => break,
        }
    }

    Ok((atom::ok(), binary_from_slice(env, &collected)).encode(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn decompress_stream_finish<'a>(
    env: Env<'a>,
    resource: ResourceArc<DecompressStream>,
) -> Result<Term<'a>, Error> {
    {
        let mut guard = resource.input.lock().unwrap();
        // Dropping the sender signals EOF to the decoder thread.
        if guard.take().is_none() {
            return Ok((atom::error(), "stream already finished").encode(env));
        }
    }

    // Block until the thread has flushed everything and exited.
    let output = resource.output.lock().unwrap();
    let mut collected: Vec<u8> = Vec::new();
    loop {
        match output.recv() {
            Ok(DecompressMsg::Chunk(chunk)) => collected.extend_from_slice(&chunk),
            Ok(DecompressMsg::Error(e)) => return Ok((atom::error(), e).encode(env)),
            // Channel disconnected: thread is done.
            Err(_) => break,
        }
    }

    Ok((atom::ok(), binary_from_slice(env, &collected)).encode(env))
}

fn binary_from_slice<'a>(env: Env<'a>, bytes: &[u8]) -> Term<'a> {
    let mut erl_bin: OwnedBinary = OwnedBinary::new(bytes.len()).unwrap();
    erl_bin.as_mut_slice().copy_from_slice(bytes);
    erl_bin.release(env).encode(env)
}

fn load(_: Env, _: Term) -> bool {
    true
}

rustler::init!("Elixir.NimbleLZ4", load = load);

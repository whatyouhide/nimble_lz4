extern crate lz4_flex;
extern crate rustler;

use rustler::types::atom;
use rustler::types::binary::{Binary, OwnedBinary};
use rustler::{Encoder, Env, Error, Term};

#[rustler::nif]
fn compress<'a>(env: Env<'a>, iolist_to_compress: Term<'a>) -> Result<Term<'a>, Error> {
    let binary_to_compress: Binary = Binary::from_iolist(iolist_to_compress).unwrap();
    let compressed_slice = lz4_flex::compress(binary_to_compress.as_slice());

    let mut erl_bin: OwnedBinary = OwnedBinary::new(compressed_slice.len()).unwrap();

    erl_bin
        .as_mut_slice()
        .copy_from_slice(compressed_slice.as_slice());

    Ok(erl_bin.release(env).encode(env))
}

#[rustler::nif]
fn decompress<'a>(
    env: Env<'a>,
    binary_to_decompress: Binary,
    uncompressed_size: usize,
) -> Result<Term<'a>, Error> {
    match lz4_flex::decompress(binary_to_decompress.as_slice(), uncompressed_size) {
        Ok(decompressed_vec) => {
            let mut erl_bin: OwnedBinary = OwnedBinary::new(decompressed_vec.len()).unwrap();
            erl_bin
                .as_mut_slice()
                .copy_from_slice(decompressed_vec.as_slice());

            Ok((atom::ok(), erl_bin.release(env)).encode(env))
        }
        Err(decompress_err) => Ok((atom::error(), decompress_err.to_string()).encode(env)),
    }
}

fn load(_: Env, _: Term) -> bool {
    true
}

rustler::init!("Elixir.NimbleLZ4", [compress, decompress], load = load);

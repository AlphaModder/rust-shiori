use std::ffi::OsString;
use std::mem;

pub trait OsStringExt {
    fn into_vec(self) -> Vec<u8>;
}

impl OsStringExt for OsString {
    fn into_vec(self) -> Vec<u8> {
        unsafe { mem::transmute(self) }
    }
}

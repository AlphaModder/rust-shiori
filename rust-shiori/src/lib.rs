extern crate winapi;
extern crate regex;
#[macro_use] extern crate rust_shiori_macros;
#[macro_use] extern crate lazy_static;

#[doc(hidden)]
pub use rust_shiori_macros::*;

pub const SHIORI_VERSION: &str = "3.0";

pub mod request;
pub mod response;

#[doc(hidden)]
pub mod internals;

pub use self::request::Request;
pub use self::response::Response;

/// This macro turns a rust crate into a SHIORI DLL. The crate must be a `dylib` or a `cdylib` for it work.
/// Its only argument is the path to the function that will be used to respond to SHIORI requests.
/// The type of this function must be `fn([Request](Request)) -> [Response](Response)`.
#[macro_export]
macro_rules! shiori {
    {$request:path} => {
        static mut PATH: Option<String> = None;

        #[no_mangle]
        pub unsafe extern "C" fn load(path: $crate::internals::HGLOBAL, len: $crate::internals::c_long) -> $crate::internals::BOOL {
            $crate::internals::load(path, len, &mut PATH)
        }

        #[no_mangle]
        pub extern "C" fn unload() -> $crate::internals::BOOL {
            $crate::internals::unload()
        }

        #[no_mangle]
        pub unsafe extern "C" fn request(request: $crate::internals::HGLOBAL, len: *mut $crate::internals::c_long) -> $crate::internals::HGLOBAL {
            $crate::internals::request(request, len, $request)
        }
    }
}

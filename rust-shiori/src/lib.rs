use std::path::PathBuf;

pub mod request;
pub mod response;

#[doc(hidden)]
pub mod internals;

pub use self::request::Request;
pub use self::response::Response;

pub const SHIORI_VERSION: &str = "3.0";

/// This macro turns a rust crate into a SHIORI DLL. The crate must be a `dylib` or a `cdylib` for it work.
/// Its only argument is a type implementing the `Shiori` trait, which will serve as the SHIORI's implementation.
#[macro_export]
macro_rules! shiori {
    {$shiori:ty} => {
        static mut SHIORI: Option<$shiori> = None;

        #[no_mangle]
        pub unsafe extern "C" fn load(path: $crate::internals::HGLOBAL, len: $crate::internals::c_long) -> $crate::internals::BOOL {
            $crate::internals::load(path, len, &mut SHIORI)
        }

        #[no_mangle]
        pub unsafe extern "C" fn unload() -> $crate::internals::BOOL {
            $crate::internals::unload(&mut SHIORI)
        }

        #[no_mangle]
        pub unsafe extern "C" fn request(request: $crate::internals::HGLOBAL, len: *mut $crate::internals::c_long) -> $crate::internals::HGLOBAL {
            $crate::internals::request(request, len, &mut SHIORI)
        }
    }
}

pub trait Shiori {
    type LoadError;
    fn load(path: PathBuf) -> Result<Self, Self::LoadError> where Self: Sized;
    fn respond(&mut self, request: Request) -> Response;
    fn unload(&mut self) { }
}
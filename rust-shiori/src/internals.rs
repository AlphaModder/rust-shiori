use winapi::um::winbase::{GlobalFree, GlobalAlloc};
use winapi::shared::minwindef::{TRUE, FALSE};
use crate::{Request, Shiori, SHIORI_VERSION};

pub use winapi::ctypes::c_long;
pub use winapi::shared::minwindef::{BOOL, HGLOBAL};

//TODO: Proper encoding handling.

pub unsafe fn load<S: Shiori>(path: HGLOBAL, len: c_long, shiori: &mut Option<S>) -> BOOL {
    // TODO: Support non-unicode encodings here.
    let path_str = std::str::from_utf8(std::slice::from_raw_parts(path as *const u8, len as usize));
    let result = match path_str.map(|s| s.parse().map(|p| S::load(p))) {
        Ok(Ok(Ok(s))) => { *shiori = Some(s); TRUE },
        _ => FALSE
    };
    GlobalFree(path);
    result
}

pub fn unload(shiori: &mut Option<impl Shiori>) -> BOOL {
    match shiori {
        Some(s) => { s.unload(); TRUE },
        None => FALSE,
    }
}

pub unsafe fn request(request: HGLOBAL, len: *mut c_long, shiori: &mut Option<impl Shiori>) -> HGLOBAL {
    match shiori {
        Some(shiori) => {
            let request_str = std::str::from_utf8(std::slice::from_raw_parts(request as *const u8, *len as usize)).unwrap();
            let response = handle_request(request_str, shiori);
            let response_ptr = GlobalAlloc(0, response.len());
            std::ptr::copy_nonoverlapping(response.as_ptr(), response_ptr as *mut u8, response.len());
            GlobalFree(request);
            *len = response.len() as i32;
            response_ptr
        }
        None => std::ptr::null_mut()
    }   
}

fn handle_request(request: &str, shiori: &mut impl Shiori) -> String {
    let request = match Request::parse(request) {
        Ok(request) => request,
        Err(_) => return format!("SHIORI/{} 400 Bad Request\r\n", SHIORI_VERSION)
    };
    let response = shiori.respond(request);
    let mut response_parts = Vec::new();
    response_parts.push(format!("SHIORI/{} {}", SHIORI_VERSION, response.status().as_str()));
    for field in response.fields_iter() {
        let value: String = response.get_field(field).unwrap().unwrap();
        response_parts.push(format!("{}: {}", field, value));
    }
    response_parts.join("\r\n")
}
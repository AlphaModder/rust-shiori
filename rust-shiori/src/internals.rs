use winapi::um::winbase::{GlobalFree, GlobalAlloc};
use winapi::shared::minwindef::{TRUE, FALSE};
use crate::{Request, Response, SHIORI_VERSION};

pub use winapi::ctypes::c_long;
pub use winapi::shared::minwindef::{BOOL, HGLOBAL};

pub unsafe fn load(path: HGLOBAL, len: c_long, PATH: &'static mut Option<String>) -> BOOL {
    let path = std::str::from_utf8(std::slice::from_raw_parts(path as *const u8, len as usize));
    match path {
        Ok(s) => { *PATH = Some(s.to_string()); return TRUE }
        Err(_) => return FALSE
    }
}

pub fn unload() -> BOOL {
    TRUE
}

pub unsafe fn request(request: HGLOBAL, len: *mut c_long, responder: impl Fn(Request) -> Response) -> HGLOBAL {
    let request_str = std::str::from_utf8(std::slice::from_raw_parts(request as *const u8, *len as usize)).unwrap();
    let response = handle_request(request_str, responder);
    let response_ptr = GlobalAlloc(0, response.len());
    std::ptr::copy_nonoverlapping(response.as_ptr(), response_ptr as *mut u8, response.len());
    GlobalFree(request);
    *len = response.len() as i32;
    response_ptr
}

fn handle_request(request: &str, responder: impl Fn(Request) -> Response) -> String {
    let request = match Request::parse(request) {
        Ok(request) => request,
        Err(_) => return format!("SHIORI/{} 400 Bad Request\r\n", SHIORI_VERSION)
    };
    let response = responder(request);
    let mut response_parts = Vec::new();
    response_parts.push(format!("SHIORI/{} {}", SHIORI_VERSION, response.status().as_str()));
    for field in response.fields_iter() {
        let value: String = response.get_field(field).unwrap().unwrap();
        response_parts.push(format!("{}: {}", field, value));
    }
    response_parts.join("\r\n")
}
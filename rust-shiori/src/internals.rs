use winapi::shared::minwindef::{TRUE, FALSE};

use shiori_hglobal::GStr;
use log::{debug, warn, error};

use crate::{Request, Shiori, SHIORI_VERSION};

pub use winapi::ctypes::c_long;
pub use winapi::shared::minwindef::{BOOL, HGLOBAL};

pub unsafe fn load<S: Shiori>(path: HGLOBAL, len: c_long, shiori: &mut Option<S>) -> BOOL {
    let path_str = GStr::capture(path, len as usize); // TODO: PR to shiori_hglobal: use c_long
    match path_str.to_ansi_str().map(|s| S::load(s.into())) {
        Ok(Ok(s)) => { *shiori = Some(s); TRUE },
        _ => { error!("The SHIORI failed to load."); FALSE },
    }
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
            let response = match GStr::capture(request, (*len) as usize).to_utf8_str().map(|s| handle_request(s, shiori)) {
                Ok(Ok(r)) => r,
                e @ _ => {
                    warn!("Recieved a corrupt or incorrectly formatted SHIORI request. Details: {:?}", e);
                    format!("SHIORI/{} 400 Bad Request\r\n\r\n", SHIORI_VERSION)
                }
            };
            let response_gstr = GStr::clone_from_slice_nofree(response.as_bytes());
            *len = response_gstr.len() as i32;
            response_gstr.handle()
        }
        None => {
            warn!("A SHIORI request was made before the SHIORI could be loaded.");
            std::ptr::null_mut()
        }
    }   
}

fn handle_request(request: &str, shiori: &mut impl Shiori) -> Result<String, ()> {
    debug!("SHIORI REQUEST:\n{}", request);
    let response = shiori.respond(Request::parse(request)?);
    let mut response_parts = Vec::new();
    response_parts.push(format!("SHIORI/{} {}", SHIORI_VERSION, response.status().as_str()));
    for field in response.fields_iter() {
        let value: String = response.get_field(field).unwrap().unwrap();
        response_parts.push(format!("{}: {}", field, value));
    }
    // Apparently these must always end with two CRLFs or the encoding detection fails! Fun!
    let response_str = response_parts.join("\r\n") + "\r\n\r\n"; 
    debug!("SHIORI RESPONSE:\n{}", response_str);
    Ok(response_str)
}
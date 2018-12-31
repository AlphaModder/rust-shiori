use std::collections::HashMap;
use std::str::FromStr;
use regex::Regex;

pub mod typed;

lazy_static! {
    static ref REQUEST_HEADER: Regex = Regex::new(
        r"(?m)((?P<method>GET|NOTIFY|TEACH)) SHIORI/(?P<version>[0-9]+\.[0-9]+)\r?$"
    ).unwrap();

    static ref REQUEST_FIELD: Regex = Regex::new(
        r"(?m)(?P<field>[^:\r\n]+): (?P<value>[^\r\n]*)\r?$"
    ).unwrap();
}

#[derive(Copy, Clone, Eq, PartialEq)]
pub enum Method {
    Get,
    Notify,
    Teach,
}

impl FromStr for Method {
    type Err = ();
    fn from_str(text: &str) -> Result<Method, ()> {
        match text {
            "GET" => Ok(Method::Get),
            "NOTIFY" => Ok(Method::Notify),
            "TEACH" => Ok(Method::Teach),
            _ => Err(())
        }
    }
}

pub struct Request {
    method: Method,
    version: String,
    fields: HashMap<String, String>,
}

impl Request {
    pub(crate) fn parse(text: &str) -> Result<Request, ()> {
        if let Some(header) = REQUEST_HEADER.captures(text) {
            let mut fields = HashMap::new();
            for captures in REQUEST_FIELD.captures_iter(text) {
                fields.insert(
                    captures.name("field").unwrap().as_str().to_string(), 
                    captures.name("value").unwrap().as_str().to_string(),
                );
            }
            return Ok(Request {
                method: Method::from_str(header.name("method").unwrap().as_str()).unwrap(),
                version: header.name("version").unwrap().as_str().to_string(),
                fields: fields,
            })
        }
        Err(())
    }

    pub fn method(&self) -> Method {
        self.method
    }

    pub fn version(&self) -> &str {
        &self.version
    }

    pub fn fields_iter(&self) -> impl Iterator<Item=&str> {
        return self.fields.keys().map(|s| s.as_str())
    }

    pub fn get_field(&self, field: &str) -> Option<&str> {
        self.fields.get(field).map(|s| s.as_str())
    }

    pub fn as_typed(&self) -> typed::TypedRequest {
        typed::TypedRequest::from_untyped(self)
    }
}
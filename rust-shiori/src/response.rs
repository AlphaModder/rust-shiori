use std::collections::HashMap;
use std::str::FromStr;

#[derive(Copy, Clone, Eq, PartialEq)]
pub enum ResponseStatus {
    OK,
    NoContent,
    NotEnough,
    Advice,
    BadRequest,
    InternalServerError,
}

impl ResponseStatus {
    pub fn as_str(&self) -> String {
        match self {
            ResponseStatus::OK => "200 OK",
            ResponseStatus::NoContent => "204 No Content",
            ResponseStatus::NotEnough => "311 Not Enough",
            ResponseStatus::Advice => "312 Advice",
            ResponseStatus::BadRequest => "400 Bad Request",
            ResponseStatus::InternalServerError => "500 Internal Server Error",
        }.to_string()
    }

    pub fn is_error(&self) -> bool {
        match self {
            ResponseStatus::BadRequest | ResponseStatus::InternalServerError => true,
            _ => false,
        }
    }
}

pub struct ResponseBuilder {
    status: Option<ResponseStatus>,
    fields: HashMap<String, String>,
}

impl ResponseBuilder {
    pub fn new() -> Self {
        ResponseBuilder { status: None, fields: HashMap::new() }
    }

    pub fn with_status(mut self, status: ResponseStatus) -> Self {
        self.status = Some(status);
        self
    }

    pub fn with_field(mut self, field_name: &str, value: &str) -> Self {
        self.fields.insert(field_name.to_string(), value.to_string());
        self
    }

    pub fn build(self) -> Option<Response> {
        Some(Response {
            status: self.status?,
            fields: self.fields
        })
    }
}

pub struct Response {
    status: ResponseStatus,
    fields: HashMap<String, String>,
}

impl Response {
    pub fn fields_iter(&self) -> impl Iterator<Item=&str> {
        return self.fields.keys().map(|s| s.as_str())
    }

    pub fn get_field<T: FromStr>(&self, field: &str) -> Option<Result<T, T::Err>> {
        self.fields.get(field).map(|s| s.parse())
    }

    pub fn status(&self) -> ResponseStatus {
        self.status
    }
}



use rlua::{Value as LuaValue, Table, Context};
use rmpv::Value;
use log::warn;

pub fn to_rmpv<'a>(table: Table<'a>, path: String) -> Value { 
    to_rmpv_inner(LuaValue::Table(table), path).unwrap() 
}

pub fn from_rmpv<'a>(ctx: &Context<'a>, map: Vec<(Value, Value)>, path: String) -> rlua::Result<Table<'a>> {
    from_rmpv_inner(ctx, Value::Map(map), path).map(|t| match t {
        Some(LuaValue::Table(table)) => table,
        _ => unreachable!(),
    })
}

fn to_rmpv_inner<'a>(value: LuaValue<'a>, path: String) -> Option<Value> {
    match value {
        LuaValue::Nil => Some(Value::Nil),
        LuaValue::Boolean(b) => Some(Value::Boolean(b)),
        LuaValue::Integer(i) => Some(Value::Integer(i.into())),
        LuaValue::Number(n) => Some(Value::F64(n)),
        LuaValue::String(s) => Some(Value::Binary(s.as_bytes().to_vec())),
        LuaValue::Table(t) => {
            if t.get_metatable().is_some() {
                warn!("The value {} has a metatable, which cannot be serialized and will not be persisted.", path)
            }
            Some(Value::Map(
                t.pairs().map(Result::unwrap).filter_map(|(k, v): (LuaValue, LuaValue)| {
                    let k_name = format!("{}.<keyname {}>", path, &lkey_name(&k));
                    let k_path = path.clone() + &lkey_seg(&k);
                    match (to_rmpv_inner(k.clone(), k_name), to_rmpv_inner(v.clone(), k_path.clone())) {
                        (Some(k), Some(v)) => return Some((k, v)),
                        (None, _) => warn!("A key of {} cannot be serialized and will not be persisted. ({:?})", path, k),
                        (Some(_), None) => warn!("The value of {} cannot be serialized and will not be persisted. ({:?})", k_path, v)
                    }
                    None
                }).collect()
            ))
        }, // TODO: detect recursive tables, needs rlua support
        _ => None
    }
}

fn from_rmpv_inner<'a>(ctx: &Context<'a>, value: Value, path: String) -> rlua::Result<Option<LuaValue<'a>>> {
    Ok(match value {
        Value::Nil => Some(LuaValue::Nil),
        Value::Boolean(b) => Some(LuaValue::Boolean(b)),
        Value::Integer(i) if i.is_i64() => Some(LuaValue::Integer(i.as_i64().unwrap())),
        Value::F32(n) => Some(LuaValue::Number(n as f64)),
        Value::F64(n) => Some(LuaValue::Number(n)),
        Value::String(s) => Some(LuaValue::String(ctx.create_string(s.as_bytes())?)),
        Value::Binary(s) => Some(LuaValue::String(ctx.create_string(&s)?)),
        Value::Array(a) => {
            let table = ctx.create_table()?;
            for (i, v) in a.into_iter().enumerate() {
                let vf = format!("{:?}", &v);
                match from_rmpv_inner(ctx, v, format!("{}[{}]", path, i))? {
                    Some(v) => table.set(i, v)?,
                    None => warn!("The value of {}[{}] is not a valid lua value and will be ignored. ({})", path, i, vf),
                }
            }
            Some(LuaValue::Table(table))
        },
        Value::Map(pairs) => {
            let table = ctx.create_table()?;
            for (k, v) in pairs {
                let (kf, vf) = (format!("{:?}", &k), format!("{:?}", &v));
                let k_name = format!("{}.<keyname {}>", path, &key_name(&k));
                let k_path = path.clone() + &key_seg(&k);
                match (from_rmpv_inner(ctx, k, k_name)?, from_rmpv_inner(ctx, v, k_path.clone())?) {
                    (Some(k), Some(v)) => table.set(k, v)?,
                    (None, _) => warn!("A key of {} is not a valid lua value and will be ignored. ({:?})", path, kf),
                    (Some(_), None) => warn!("The value of {} is not a valid lua value and will be ignored. ({:?})", k_path, vf)
                }
            }
            Some(LuaValue::Table(table))
        },
        _ => None,
    })
}

fn key_seg(value: &Value) -> String {
    match value {
        Value::Nil => "[nil]".to_string(),
        Value::Boolean(b) => format!("[{}]", b).to_string(),
        Value::Integer(i) => format!("[{}]", i).to_string(),
        Value::F32(n) => format!("[{}]", n).to_string(),
        Value::F64(n) => format!("[{}]", n).to_string(),
        Value::String(s) => format!(".{}", s).to_string(),
        Value::Binary(b) => format!(".{}", String::from_utf8_lossy(&b)),
        Value::Array(_) | Value::Map(_) => "[<table>]".to_string(),
        _ => "<error>".to_string(),
    }
}

fn lkey_seg<'a>(value: &LuaValue<'a>) -> String {
    match value {
        LuaValue::Nil => "[nil]".to_string(),
        LuaValue::Boolean(b) => format!("[{}]", b).to_string(),
        LuaValue::Integer(i) => format!("[{}]", i).to_string(),
        LuaValue::Number(n) => format!("[{}]", n).to_string(),
        LuaValue::String(s) => format!(".{}", String::from_utf8_lossy(s.as_bytes())),
        LuaValue::Table(_) => "[<table>]".to_string(),
        _ => "<error>".to_string(),
    }
}

fn key_name(value: &Value) -> String {
    match value {
        Value::Nil => "nil".to_string(),
        Value::Boolean(b) => format!("{}", b).to_string(),
        Value::Integer(i) => format!("{}", i).to_string(),
        Value::F32(n) => format!("{}", n).to_string(),
        Value::F64(n) => format!("{}", n).to_string(),
        Value::String(s) => format!("\"{}\"", s).to_string(),
        Value::Binary(b) => format!("\"{}\"", String::from_utf8_lossy(&b)),
        Value::Array(_) | Value::Map(_) => "<table>".to_string(),
        _ => "<error>".to_string(),
    }
}

fn lkey_name<'a>(value: &LuaValue<'a>) -> String {
    match value {
        LuaValue::Nil => "nil".to_string(),
        LuaValue::Boolean(b) => format!("{}", b).to_string(),
        LuaValue::Integer(i) => format!("{}", i).to_string(),
        LuaValue::Number(n) => format!("{}", n).to_string(),
        LuaValue::String(s) => format!("\"{}\"", String::from_utf8_lossy(s.as_bytes())),
        LuaValue::Table(_) => "<table>".to_string(),
        _ => "<error>".to_string(),
    }
}
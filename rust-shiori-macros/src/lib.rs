extern crate syn;
extern crate quote;
extern crate proc_macro;
use std::env;
use quote::quote;
use syn::export::TokenStream2 as TokenStream;
use syn::export::Span;

#[proc_macro_derive(RequestType, attributes(shiori))]
pub fn derive_request_type(input: proc_macro::TokenStream) -> proc_macro::TokenStream {
    let ast = syn::parse(input).unwrap();
    request_type::derive(ast).into()
}

fn wrap_in_const(trait_: &str, ty: &syn::Ident, code: TokenStream) -> TokenStream {
    let dummy_const = syn::Ident::new(
        &format!("_IMPL_{}_FOR_{}", trait_, ty.to_string().trim_start_matches("r#").to_owned()),
        Span::call_site(),
    );

    if env::var("CARGO_PKG_NAME").unwrap() == "rust-shiori" {
        return quote! {
            #[allow(non_upper_case_globals, unused_attributes, unused_qualifications)]
            const #dummy_const: () = {
                use crate as _rust_shiori;
                #code
            };
        }
    }
    else {
        return quote! {
            #[allow(non_upper_case_globals, unused_attributes, unused_qualifications)]
            const #dummy_const: () = {
                #[allow(unknown_lints)]
                #[cfg_attr(feature = "cargo-clippy", allow(useless_attribute))]
                #[allow(rust_2018_idioms)]
                extern crate rust_shiori as _rust_shiori;
                #code
            };
        }
    }
}

mod request_type {
    use syn::{Token, export::{TokenStream2 as TokenStream, Span}};
    use quote::quote;

    pub fn parse_shiori_attr<'a>(attr: &'a syn::Attribute, key: &str) -> Option<syn::Lit> {
        if attr.path.segments.len() == 1 && attr.path.segments[0].ident == "shiori" {
            if let Ok(syn::Meta::List(mlist)) = attr.parse_meta() {
                if let Some(syn::NestedMeta::Meta(syn::Meta::NameValue(nv))) = mlist.nested.iter().nth(0) {
                    if nv.ident == key {
                        return Some(nv.lit.clone())
                    }
                }
            }
        }
        None
    }

    pub fn derive(mut ast: syn::DeriveInput) -> TokenStream {
        let name = &ast.ident;
        let id = ast.attrs.iter().enumerate().filter_map(|(n, a)| {
            if let Some(syn::Lit::Str(ref s)) = parse_shiori_attr(a, "id") {
                return Some((s.clone(), n))
            }
            None
        }).nth(0);
        if let Some((_, i)) = id {
            ast.attrs.remove(i);
        }
        let id = id.map(|i| i.0).unwrap_or(syn::LitStr::new(&name.to_string(), name.span()));

        let (fields, make_init) = match ast.data {
            syn::Data::Struct(
                syn::DataStruct { 
                    fields: syn::Fields::Named(syn::FieldsNamed { named: ref mut f, .. }), .. 
                }
            ) |
            syn::Data::Union(
                syn::DataUnion { 
                    fields: syn::FieldsNamed { named: ref mut f, .. }, .. 
                }
            ) => (Some(f), Box::new(|init| quote! { #name { #init } }) as Box<Fn(_) -> _>),
            syn::Data::Struct(
                syn::DataStruct { 
                    fields: syn::Fields::Unnamed(syn::FieldsUnnamed { unnamed: ref mut f, .. }), .. 
                }
            ) => (Some(f), Box::new(|init| quote! { #name ( #init ) }) as Box<dyn Fn(_) -> _>),
            syn::Data::Struct(
                syn::DataStruct { 
                    fields: syn::Fields::Unit, .. 
                }
            ) => (None, Box::new(|_| quote! { #name }) as Box<dyn Fn(_) -> _>),
            syn::Data::Enum(_) => panic!("#[derive(RequestType)] does not support enums!"),
        };

        let initializer = match fields {
            Some(f) => {
                let mut punc = syn::punctuated::Punctuated::<_, Token![,]>::new();
                punc.extend(f.iter_mut().map(|f| {
                    let field_ident = &f.ident;
                    let shiori_field = f.attrs.iter().enumerate().filter_map(
                        |(n, a)| {
                            if let syn::AttrStyle::Outer = a.style {
                                if let Some(syn::Lit::Str(ref s)) = parse_shiori_attr(a, "field") {
                                    return Some((s.clone(), n))
                                }
                            }
                            None
                        }
                    ).nth(0);
                    if let Some((_, i)) = shiori_field {
                        f.attrs.remove(i);
                    }
                    let shiori_field = shiori_field.map(|f| f.0).or(field_ident.as_ref().map(|i| syn::LitStr::new(&i.to_string(), i.span())));
                    let value = quote! { 
                        <_ as _rust_shiori::request::FromRequestField>::from_request_field(untyped.get_field(#shiori_field))? 
                    };
                    match field_ident {
                        Some(ident) => { quote! { #ident: #value } },
                        None => value
                    }
                }));
                make_init(punc)
            }
            None => quote! { #name }
        };

        let (_, ty_generics, where_clause) = ast.generics.split_for_impl();

        let lifetime_def = {
            let mut lifetime_name = "u".to_string();
            while ast.generics.lifetimes().find(|l| l.lifetime.ident == lifetime_name).is_some() {
                lifetime_name = format!("_{}", lifetime_name);
            }
            let mut lifetime = syn::LifetimeDef::new(syn::Lifetime::new(&format!("'{}", lifetime_name), Span::call_site()));
            lifetime.bounds.extend(ast.generics.lifetimes().map(|l| l.lifetime.clone()));
            lifetime
        };

        let lifetime = &lifetime_def.lifetime;

        let mut new_generics = ast.generics.clone();
        new_generics.params.push(syn::GenericParam::Lifetime(lifetime_def.clone()));
        let (impl_generics, ..) = new_generics.split_for_impl();

        crate::wrap_in_const("REQUESTTYPE", name, quote! {
            #[automatically_derived]
            impl #impl_generics _rust_shiori::request::typed::RequestType<#lifetime> for #name #ty_generics #where_clause {
                const ID: &'static str = #id;
                fn from_untyped(untyped: &#lifetime _rust_shiori::request::Request) -> Result<Self, ()> {
                    if untyped.get_field("ID") != Some(Self::ID) { return Err(()) }
                    Ok(#initializer)
                }
            }
        }) 
    }
}
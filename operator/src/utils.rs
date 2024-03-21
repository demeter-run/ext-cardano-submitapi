use argon2::Argon2;
use base64::{engine::general_purpose, Engine};
use bech32::ToBase32;
use kube::{
    api::{Patch, PatchParams},
    core::DynamicObject,
    discovery::ApiResource,
    Api, Client, ResourceExt,
};
use serde_json::json;

use crate::{get_config, Error, Network, SubmitApiPort};

pub async fn patch_resource_status(
    client: Client,
    namespace: &str,
    api_resource: ApiResource,
    name: &str,
    payload: serde_json::Value,
) -> Result<(), kube::Error> {
    let api: Api<DynamicObject> = Api::namespaced_with(client, namespace, &api_resource);

    let status = json!({ "status": payload });
    let patch_params = PatchParams::default();
    api.patch_status(name, &patch_params, &Patch::Merge(status))
        .await?;
    Ok(())
}

pub fn build_hostname(
    network: &Network,
    key: &str,
    submitapi_version: &Option<String>,
) -> (String, String) {
    let config = get_config();
    let extension_subdomain = &config.extension_subdomain;
    let dns_zone = &config.dns_zone;
    let version = submitapi_version
        .clone()
        .unwrap_or(config.default_submitapi_version.to_string());

    let hostname = format!("{network}-{version}.{extension_subdomain}.{dns_zone}");
    let hostname_key = format!("{key}.{network}-{version}.{extension_subdomain}.{dns_zone}");

    (hostname, hostname_key)
}

pub async fn build_api_key(crd: &SubmitApiPort) -> Result<String, Error> {
    let namespace = crd.namespace().unwrap();

    let name = format!("submitapi-auth-{}", &crd.name_any());

    let password = format!("{}{}", name, namespace).as_bytes().to_vec();

    let config = get_config();
    let salt = config.api_key_salt.as_bytes();

    let mut output = vec![0; 16];

    let argon2 = Argon2::default();
    let _ = argon2.hash_password_into(password.as_slice(), salt, &mut output);

    let base64 = general_purpose::URL_SAFE_NO_PAD.encode(output);
    let with_bech = bech32::encode(
        "dmtr_submitapi",
        base64.to_base32(),
        bech32::Variant::Bech32,
    )
    .unwrap();

    Ok(with_bech)
}

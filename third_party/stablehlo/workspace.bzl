"""Provides the repository macro to import StableHLO."""

load("//third_party:repo.bzl", "tf_http_archive", "tf_mirror_urls")

def repo():
    #
    STABLEHLO_COMMIT = "04c5a341abe43f50ea2f8eca97fcc07763230c00"
    STABLEHLO_SHA256 = "3eb4968cd57544850bc3b2ea2f605501ef43e9f245aee0bf0c141d4748c2d277"
    #

    tf_http_archive(
        name = "stablehlo",
        sha256 = STABLEHLO_SHA256,
        strip_prefix = "stablehlo-{commit}".format(commit = STABLEHLO_COMMIT),
        urls = tf_mirror_urls("https://github.com/openxla/stablehlo/archive/{commit}.zip".format(commit = STABLEHLO_COMMIT)),
        patch_file = [
            "//third_party/stablehlo:temporary.patch",  # Autogenerated, don't remove.
        ],
    )

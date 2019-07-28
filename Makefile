all: generate

########################
# setup
########################

apitools_img := gcr.io/istio-testing/api-build-tools:2019-07-29
websitetools_img := gcr.io/istio-testing/website-tools:2019-07-25

pwd := $(shell pwd)
mount_dir := /src
repo_dir := istio.io/api
repo_mount := $(mount_dir)/istio.io/api
out_path = .
uid := $(shell id -u)

protoc = docker run --user $(uid) -v /etc/passwd:/etc/passwd:ro --rm -v $(pwd):$(repo_mount) -w $(mount_dir) $(apitools_img) protoc -I/usr/include/protobuf -I$(repo_dir)

run = docker run --user $(uid) -v /etc/passwd:/etc/passwd:ro --rm -v $(pwd):$(repo_mount) -w $(repo_mount) $(apitools_img)
protolock = $(run) protolock
protolock_release = $(run) /bin/bash $(repo_mount)/scripts/check-release-locks.sh
prototool = $(run) prototool
annotations_prep = $(run) annotations_prep

htmlproofer = docker run --user $(uid) -v /etc/passwd:/etc/passwd:ro --rm -v $(pwd):$(repo_mount) -w $(mount_dir) $(websitetools_img) htmlproofer

########################
# protoc_gen_gogo*
########################

gogofast_plugin_prefix := --gogofast_out=plugins=grpc,
gogoslick_plugin_prefix := --gogoslick_out=plugins=grpc,

comma := ,
empty :=
space := $(empty) $(empty)

importmaps := \
	gogoproto/gogo.proto=github.com/gogo/protobuf/gogoproto \
	google/protobuf/any.proto=github.com/gogo/protobuf/types \
	google/protobuf/descriptor.proto=github.com/gogo/protobuf/protoc-gen-gogo/descriptor \
	google/protobuf/duration.proto=github.com/gogo/protobuf/types \
	google/protobuf/struct.proto=github.com/gogo/protobuf/types \
	google/protobuf/timestamp.proto=github.com/gogo/protobuf/types \
	google/protobuf/wrappers.proto=github.com/gogo/protobuf/types \
	google/rpc/status.proto=github.com/gogo/googleapis/google/rpc \
	google/rpc/code.proto=github.com/gogo/googleapis/google/rpc \
	google/rpc/error_details.proto=github.com/gogo/googleapis/google/rpc \

# generate mapping directive with M<proto>:<go pkg>, format for each proto file
mapping_with_spaces := $(foreach map,$(importmaps),M$(map),)
gogo_mapping := $(subst $(space),$(empty),$(mapping_with_spaces))

gogofast_plugin := $(gogofast_plugin_prefix)$(gogo_mapping):$(out_path)
gogoslick_plugin := $(gogoslick_plugin_prefix)$(gogo_mapping):$(out_path)

########################
# protoc_gen_python
########################

python_output_path := python/istio_api
protoc_gen_python_prefix := --python_out=,
protoc_gen_python_plugin := $(protoc_gen_python_prefix):$(repo_dir)/$(python_output_path)

########################
# protoc_gen_docs
########################

protoc_gen_docs_plugin := --docs_out=warnings=true,dictionary=$(repo_dir)/dictionaries/en-US,custom_word_list=$(repo_dir)/dictionaries/custom.txt,mode=html_fragment_with_front_matter:$(repo_dir)/
protoc_gen_docs_plugin_for_networking := --docs_out=warnings=true,dictionary=$(repo_dir)/dictionaries/en-US,custom_word_list=$(repo_dir)/dictionaries/custom.txt,per_file=true,mode=html_fragment_with_front_matter:$(repo_dir)/

#####################
# Generation Rules
#####################

generate: \
	generate-mcp \
	generate-mesh \
	generate-mixer \
	generate-networking \
	generate-rbac \
	generate-authn \
	generate-envoy \
	generate-policy \
	generate-annotations

#####################
# mcp/...
#####################

mcp_path := mcp/v1alpha1
mcp_protos := $(shell find $(mcp_path) -type f -name '*.proto' | sort)
mcp_pb_gos := $(mcp_protos:.proto=.pb.go)
mcp_pb_pythons := $(patsubst $(mcp_path)/%.proto,$(python_output_path)/$(mcp_path)/%_pb2.py,$(mcp_protos))
mcp_pb_doc := $(mcp_path)/istio.mcp.v1alpha1.pb.html

$(mcp_pb_gos) $(mcp_pb_doc) $(mcp_pb_pythons): $(mcp_protos)
	@$(protolock) status
	@$(protoc) $(gogofast_plugin) $(protoc_gen_docs_plugin)$(mcp_path) $(protoc_gen_python_plugin) $^

generate-mcp: $(mcp_pb_gos) $(mcp_pb_doc) $(mcp_pb_pythons)

clean-mcp:
	@rm -fr $(mcp_pb_gos) $(mcp_pb_doc) $(mcp_pb_pythons)

#####################
# mesh/...
#####################

mesh_path := mesh/v1alpha1
mesh_protos := $(shell find $(mesh_path) -type f -name '*.proto' | sort)
mesh_pb_gos := $(mesh_protos:.proto=.pb.go)
mesh_pb_pythons := $(patsubst $(mesh_path)/%.proto,$(python_output_path)/$(mesh_path)/%_pb2.py,$(mesh_protos))
mesh_pb_doc := $(mesh_path)/istio.mesh.v1alpha1.pb.html

$(mesh_pb_gos) $(mesh_pb_doc) $(mesh_pb_pythons): $(mesh_protos)
	@$(protolock) status
	@$(protoc) $(gogofast_plugin) $(protoc_gen_docs_plugin)$(mesh_path) $(protoc_gen_python_plugin) $^

generate-mesh: $(mesh_pb_gos) $(mesh_pb_doc) $(mesh_pb_pythons)

clean-mesh:
	@rm -fr $(mesh_pb_gos) $(mesh_pb_doc) $(mesh_pb_pythons)

#####################
# policy/...
#####################

policy_v1beta1_path := policy/v1beta1
policy_v1beta1_protos := $(shell find $(policy_v1beta1_path) -maxdepth 1 -type f -name '*.proto' | sort)
policy_v1beta1_pb_gos := $(policy_v1beta1_protos:.proto=.pb.go)
policy_v1beta1_pb_pythons := $(patsubst $(policy_v1beta1_path)/%.proto,$(python_output_path)/$(policy_v1beta1_path)/%_pb2.py,$(policy_protos))
policy_v1beta1_pb_doc := $(policy_v1beta1_path)/istio.policy.v1beta1.pb.html

$(policy_v1beta1_pb_gos) $(policy_v1beta1_pb_doc) $(policy_v1beta1_pb_pythons): $(policy_v1beta1_protos)
	@$(protolock) status
	@$(protoc) $(gogoslick_plugin) $(protoc_gen_docs_plugin)$(policy_v1beta1_path) $(protoc_gen_python_plugin) $^

generate-policy: $(policy_v1beta1_pb_gos) $(policy_v1beta1_pb_doc) $(policy_v1beta1_pb_pythons)

clean-policy:
	@rm -fr $(policy_v1beta1_pb_gos) policy/v1beta1/fixed_cfg.pb.go $(policy_v1beta1_pb_doc) $(policy_v1beta1_pb_pythons)

#####################
# mixer/...
#####################

mixer_v1_path := mixer/v1
mixer_v1_protos :=  $(shell find $(mixer_v1_path) -maxdepth 1 -type f -name '*.proto' | sort)
mixer_v1_pb_gos := $(mixer_v1_protos:.proto=.pb.go)
mixer_v1_pb_pythons := $(mixer_v1_protos:.proto=_pb2.py)
mixer_v1_pb_pythons := $(patsubst $(mixer_v1_path)/%.proto,$(python_output_path)/$(mixer_v1_path)/%_pb2.py,$(mixer_v1_protos))
mixer_v1_pb_doc := $(mixer_v1_path)/istio.mixer.v1.pb.html

mixer_config_client_path := mixer/v1/config/client
mixer_config_client_protos := $(shell find $(mixer_config_client_path) -maxdepth 1 -type f -name '*.proto' | sort)
mixer_config_client_pb_gos := $(mixer_config_client_protos:.proto=.pb.go)
mixer_config_client_pb_pythons := $(mixer_config_client_protos:.proto=_pb2.py)
mixer_config_client_pb_pythons := $(patsubst $(mixer_config_client_path)/%.proto,$(python_output_path)/$(mixer_client_config_path)/%_pb2.py,$(mixer_client_config_protos))
mixer_config_client_pb_doc := $(mixer_config_client_path)/istio.mixer.v1.config.client.pb.html

mixer_adapter_model_v1beta1_path := mixer/adapter/model/v1beta1
mixer_adapter_model_v1beta1_protos := $(shell find $(mixer_adapter_model_v1beta1_path) -maxdepth 1 -type f -name '*.proto' | sort)
mixer_adapter_model_v1beta1_pb_gos := $(mixer_adapter_model_v1beta1_protos:.proto=.pb.go)
mixer_adapter_model_pb_pythons := $(patsubst $(mixer_adapter_model_path)/%.proto,$(python_output_path)/$(mixer_adapter_model_path)/%_pb2.py,$(mixer_adapter_model_protos))
mixer_adapter_model_v1beta1_pb_doc := $(mixer_adapter_model_v1beta1_path)/istio.mixer.adapter.model.v1beta1.pb.html

$(mixer_v1_pb_gos) $(mixer_v1_pb_doc) $(mixer_v1_pb_pythons): $(mixer_v1_protos)
	@$(protolock) status
	@$(protoc) $(gogoslick_plugin) $(protoc_gen_docs_plugin)$(mixer_v1_path) $(protoc_gen_python_plugin) $^

$(mixer_config_client_pb_gos) $(mixer_config_client_pb_doc)  $(mixer_config_client_pb_pythons): $(mixer_config_client_protos)
	@$(protolock) status
	@$(protoc) $(gogoslick_plugin) $(protoc_gen_docs_plugin)$(mixer_config_client_path) $(protoc_gen_python_plugin) $^

$(mixer_adapter_model_v1beta1_pb_gos) $(mixer_adapter_model_v1beta1_pb_doc) $(mixer_adapter_model_v1beta1_pb_pythons): $(mixer_adapter_model_v1beta1_protos)
	@$(protolock) status
	@$(protoc) $(gogoslick_plugin) $(protoc_gen_docs_plugin)$(mixer_adapter_model_v1beta1_path) $(protoc_gen_python_plugin)  $^

generate-mixer: \
	$(mixer_v1_pb_gos) $(mixer_v1_pb_doc) $(mixer_v1_pb_pythons) \
	$(mixer_config_client_pb_gos) $(mixer_config_client_pb_doc) $(mixer_config_client_pb_pythons) \
	$(mixer_adapter_model_v1beta1_pb_gos) $(mixer_adapter_model_v1beta1_pb_doc) $(mixer_adapter_model_v1beta1_pb_pythons)

clean-mixer:
	@rm -fr $(mixer_v1_pb_gos) $(mixer_v1_pb_doc) $(mixer_v1_pb_pythons)
	@rm -fr $(mixer_config_client_pb_gos) $(mixer_config_client_pb_doc) $(mixer_config_client_pb_pythons)
	@rm -fr $(mixer_adapter_model_v1beta1_pb_gos) $(mixer_adapter_model_v1beta1_pb_doc) $(mixer_adapter_model_v1beta1_pb_pythons)

#####################
# networking/...
#####################

networking_v1alpha3_path := networking/v1alpha3
networking_v1alpha3_protos := $(shell find networking/v1alpha3 -type f -name '*.proto' | sort)
networking_v1alpha3_pb_gos := $(networking_v1alpha3_protos:.proto=.pb.go)
networking_v1alpha3_pb_pythons := $(patsubst $(networking_v1alpha3_path)/%.proto,$(python_output_path)/$(networking_v1alpha3_path)/%_pb2.py,$(networking_protos))
networking_v1alpha3_pb_docs := $(networking_v1alpha3_protos:.proto=.pb.html)

$(networking_v1alpha3_pb_gos) $(networking_v1alpha3_pb_docs) $(networking_v1alpha3_pb_pythons): $(networking_v1alpha3_protos)
	@$(protolock) status
	@$(protoc) $(gogofast_plugin) $(protoc_gen_docs_plugin_for_networking)$(networking_v1alpha3_path) $(protoc_gen_python_plugin) $^

generate-networking: $(networking_v1alpha3_pb_gos) $(networking_v1alpha3_pb_docs) $(networking_v1alpha3_pb_pythons)

clean-networking:
	@rm -fr $(networking_v1alpha3_pb_gos) $(networking_v1alpha3_pb_docs) $(networking_v1alpha3_pb_pythons)

#####################
# rbac/...
#####################

rbac_v1alpha1_path := rbac/v1alpha1
rbac_v1alpha1_protos := $(shell find $(rbac_v1alpha1_path) -type f -name '*.proto' | sort)
rbac_v1alpha1_pb_gos := $(rbac_v1alpha1_protos:.proto=.pb.go)
rbac_v1alpha1_pb_pythons := $(patsubst $(rbac_v1alpha1_path)/%.proto,$(python_output_path)/$(rbac_v1alpha1_path)/%_pb2.py,$(rbac_protos))
rbac_v1alpha1_pb_doc := $(rbac_v1alpha1_path)/istio.rbac.v1alpha1.pb.html

$(rbac_v1alpha1_pb_gos) $(rbac_v1alpha1_pb_doc)  $(rbac_v1alpha1_pb_pythons): $(rbac_v1alpha1_protos)
	@$(protolock) status
	@$(protoc) $(gogofast_plugin) $(protoc_gen_docs_plugin)$(rbac_v1alpha1_path) $(protoc_gen_python_plugin) $^

generate-rbac: $(rbac_v1alpha1_pb_gos) $(rbac_v1alpha1_pb_doc) $(rbac_v1alpha1_protos)

clean-rbac:
	@rm -fr $(rbac_v1alpha1_pb_gos) $(rbac_v1alpha1_pb_doc) $(rbac_v1alpha1_pb_pythons)

#####################
# authentication/...
#####################

authn_v1alpha1_path := authentication/v1alpha1
authn_v1alpha1_protos := $(shell find $(authn_v1alpha1_path) -type f -name '*.proto' | sort)
authn_v1alpha1_pb_gos := $(authn_v1alpha1_protos:.proto=.pb.go)
authn_v1alpha1_pb_pythons := $(patsubst $(authn_v1alpha1_path)/%.proto,$(python_output_path)/$(authn_v1alpha1_path)/%_pb2.py,$(authn_protos))
authn_v1alpha1_pb_doc := $(authn_v1alpha1_path)/istio.authentication.v1alpha1.pb.html

$(authn_v1alpha1_pb_gos) $(authn_v1alpha1_pb_doc) $(authn_v1alpha1_pb_pythons): $(authn_v1alpha1_protos)
	@$(protolock) status
	@$(protoc) $(gogofast_plugin) $(protoc_gen_docs_plugin)$(authn_v1alpha1_path) $(protoc_gen_python_plugin) $^

generate-authn: $(authn_v1alpha1_pb_gos) $(authn_v1alpha1_pb_doc) $(authn_v1alpha1_pb_pythons)

clean-authn:
	@rm -fr $(authn_v1alpha1_pb_gos) $(authn_v1alpha1_pb_doc) $(authn_v1alpha1_pb_pythons)

#####################
# envoy/...
#####################

envoy_path := envoy
envoy_protos := $(shell find $(envoy_path) -type f -name '*.proto' | sort)
envoy_pb_gos := $(envoy_protos:.proto=.pb.go)
envoy_pb_pythons := $(patsubst $(envoy_path)/%.proto,$(python_output_path)/$(envoy_path)/%_pb2.py,$(envoy_protos))

$(envoy_pb_gos): %.pb.go : %.proto
	@$(protolock) status
	@$(protoc) $(gogofast_plugin) $<

$(envoy_pb_pythons): $(envoy_protos)
	@$(protolock) status
	@$(protoc) $(protoc_gen_python_plugin) $^

generate-envoy: $(envoy_pb_gos) $(envoy_pb_pythons)

clean-envoy:
	@rm -fr $(envoy_pb_gos) $(envoy_pb_pythons)

#####################
# annotation/...
#####################

annotations_path := annotation
annotations_pb_go := $(annotations_path)/annotations.gen.go
annotations_pb_doc := $(annotations_path)/annotations.pb.html

$(annotations_pb_go) $(annotations_pb_doc): $(annotations_path)/annotations.yaml
	@$(annotations_prep) --input $(annotations_path)/annotations.yaml --output $(annotations_pb_go) --html_output $(annotations_pb_doc)

generate-annotations: $(annotations_pb_go) $(annotations_pb_doc)

clean-annotations:
	@rm -fr $(annotations_pb_go) $(annotations_pb_doc)

#####################
# Protolock
#####################

proto-commit:
	@$(protolock) commit

proto-commit-force:
	@$(protolock) commit --force

proto-status:
	@$(protolock) status

release-lock-status:
	@$(protolock_release)

#####################
# Lint
#####################

lint:
	@scripts/check_license.sh
	@$(prototool) lint --protoc-bin-path=/usr/bin/protoc --protoc-wkt-path=/usr/include/protobuf
	@$(htmlproofer) . --url-swap "istio.io:preliminary.istio.io" --assume-extension --check-html --check-external-hash --check-opengraph --timeframe 2d --storage-dir $(repo_dir)/.htmlproofer --url-ignore "/localhost/"

#####################
# Cleanup
#####################

clean: \
	clean-mcp \
	clean-mesh \
	clean-mixer \
	clean-networking \
	clean-rbac \
	clean-authn \
	clean-envoy \
	clean-policy \
	clean-annotations \

include Makefile.common.mk

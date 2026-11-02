# shellcheck shell=bash
# model: Parakeet TDT 0.6B v3 (Q4_K_M, 485 MB), 25 European languages including
# English and Spanish. Pinned revision, verified with sha256. Handy picks it up
# from its models directory.

MODEL_REPO=handy-computer/parakeet-tdt-0.6b-v3-gguf
MODEL_REV=85ac09ea12fc4b1112fa76810059364bc6adc9de
MODEL_FILE=parakeet-tdt-0.6b-v3-Q4_K_M.gguf
MODEL_SHA256=b68557be1e3c40207fd7c4bd9d63f1d3316b963f15325bfb0cc16a8bb0ffd181
# shellcheck disable=SC2034 # used in lib/doctor.sh
MODEL_SIZE=485425504
# shellcheck disable=SC2034 # used in config.sh and lib/doctor.sh
MODEL_ID="$MODEL_REPO/$MODEL_FILE"
MODEL_PATH="$HANDY_DATA/models/$MODEL_FILE"

model_status() {
	[ -f "$MODEL_PATH" ]
}

model_install() {
	fetch_verified "https://huggingface.co/$MODEL_REPO/resolve/$MODEL_REV/$MODEL_FILE" \
		sha256 "$MODEL_SHA256" "$MODEL_PATH"
}

model_uninstall() {
	rm -f "$MODEL_PATH" "$MODEL_PATH.stt-local.part"
}

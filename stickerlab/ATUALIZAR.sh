#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
cd "${STICKERLAB_DIR:-$HOME/StickerLab-Bot-3.0}"
for tool in node git curl sha256sum; do
  command -v "$tool" >/dev/null || { echo "Falta $tool. Instale pelo Termux antes de atualizar." >&2; exit 1; }
done
version=$(node -p 'require("./package.json").version')
case "$version" in
  3.4.0) echo 'StickerLab 3.4 ja esta instalado.'; exit 0 ;;
  3.3.0) ;;
  *) echo "Esta atualizacao exige a versao 3.3.0 (encontrada: $version). Nada alterado." >&2; exit 1 ;;
esac
files=(INSTALAR.sh LEIA-ME.md src/bot.mjs src/main.mjs src/media.mjs tests/bot.test.mjs tests/media.test.mjs package.json)
root="$PWD"
work=$(mktemp -d)
backup=''
committing=0
cleanup() {
  local status=$?
  trap - EXIT
  if [[ $committing == 1 ]]; then
    echo 'Atualizacao interrompida; restaurando codigo anterior.' >&2
    for f in "${files[@]}"; do cp -p -- "$backup/$f" "$root/$f" || echo "Restaure $f manualmente a partir de $backup" >&2; done
  fi
  rm -rf -- "$work"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
patch_url='https://raw.githubusercontent.com/gbZyuuu/gbZyuuu.github.io/19d3cd41265f6f28c940203099c7f97eb196d745/stickerlab/3.4.patch'
if [[ -n ${STICKERLAB_PATCH_FILE:-} ]]; then
  cp -- "$STICKERLAB_PATCH_FILE" "$work/update.patch"
else
  echo 'Baixando a correcao oficial do projeto StickerLab 3.4...'
  curl --proto '=https' --tlsv1.2 -fsSL --retry 2 --connect-timeout 15 --max-time 120 "$patch_url" -o "$work/update.patch"
fi
printf '%s  %s\n' 6a1310c364e37126275d4485c4956a9ec39b80e4c528fa1423fb706019d6d86b "$work/update.patch" | sha256sum -c -
mkdir -p "$work/stage"
for f in "${files[@]}"; do
  [[ -f "$f" && ! -L "$f" ]] || { echo "Arquivo ausente ou invalido: $f" >&2; exit 1; }
  mkdir -p "$(dirname "$work/stage/$f")"
  cp -p -- "$f" "$work/stage/$f"
done
(
  cd "$work/stage"
  git apply --check --unidiff-zero "$work/update.patch"
  git apply --unidiff-zero "$work/update.patch"
  sha256sum -c - <<'SUMS'
fc1f877e3347913a0ce9170ee74bba48235c018a54d33272e11b3b0c15725724  INSTALAR.sh
f5a0d1e2eb9ac8a784adeeaa67aef0957d11a4fc5566708d83d0033d60ff6344  LEIA-ME.md
af1cc63d43ba09002e1eaf35f1494816418b3f68a189d71384f3c1b15a3a7c27  package.json
46f2096ce548f318bffda3d1eeb94d972d6fe3cad31669e8a3eb1c9868566a7d  src/bot.mjs
84e70335d7994b073653312ef0b5f14fe629e4a8a5842e825ca23edb4f8f0d5c  src/main.mjs
31d4078abc1804a6cf64eda5020dfe49bc238eb89df1b7406f45cc7e769f7c27  src/media.mjs
80e31006035447b8f9a9c68e9e4dd8ab762878a0a7fd6c40402b683a8533ce2c  tests/bot.test.mjs
386b4de7c4a8a1228fa282566e0e1483513f2370b56c6305ebe716c041f16dd6  tests/media.test.mjs
SUMS
  for f in src/*.mjs tests/*.mjs; do node --check "$f"; done
  bash -n INSTALAR.sh
)
mkdir -p "$HOME/.stickerlab-update-backups"
backup=$(mktemp -d "$HOME/.stickerlab-update-backups/3.3.0-XXXXXXXX")
for f in "${files[@]}"; do
  mkdir -p "$(dirname "$backup/$f")"
  cp -p -- "$f" "$backup/$f"
done
committing=1
for f in "${files[@]}"; do cp -p -- "$work/stage/$f" "$f"; done
committing=0
printf '\n[OK] StickerLab Bot 3.4.0 atualizado!\nBackup do codigo: %s\nSessao, whitelist e node_modules nao foram alterados.\nExecute: bash INICIAR.sh\n' "$backup"

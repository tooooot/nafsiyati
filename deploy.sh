#!/bin/bash
# ينزّل آخر بناء ويب ناجح من GitHub وينشره على https://nafsiyati.wardyat.net
set -e
cd /root/nafsiyati
T=$(tr -d '\n ' </root/env/github_token.txt)
R=$(curl -s -H "Authorization: Bearer $T" "https://api.github.com/repos/tooooot/nafsiyati/actions/runs?status=success&per_page=1" | python3 -I -c "import sys,json;print(json.load(sys.stdin)['workflow_runs'][0]['id'])")
A=$(curl -s -H "Authorization: Bearer $T" https://api.github.com/repos/tooooot/nafsiyati/actions/runs/$R/artifacts | python3 -I -c "import sys,json;print(json.load(sys.stdin)['artifacts'][0]['id'])")
mkdir -p /tmp/nz && curl -sL -H "Authorization: Bearer $T" -o /tmp/nz/web.zip https://api.github.com/repos/tooooot/nafsiyati/actions/artifacts/$A/zip
rm -rf /tmp/nz/new && unzip -q -o /tmp/nz/web.zip -d /tmp/nz/new
V=$(date +%s)
sed -i -E "s#\"mainJsPath\":\"main\.dart\.js(\?v=[0-9]+)?\"#\"mainJsPath\":\"main.dart.js?v=$V\"#" /tmp/nz/new/flutter_bootstrap.js
sed -i -E "s#flutter_bootstrap\.js(\?v=[0-9]+)?#flutter_bootstrap.js?v=$V#g" /tmp/nz/new/index.html
rsync -a --delete /tmp/nz/new/ site/
echo "نُشر: run $R"

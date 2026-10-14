#!/bin/zsh
cd "$(dirname "$0")"
/usr/bin/python3 Scripts/update_iphone.py --force
read -k 1 '?Pressione uma tecla para fechar...'

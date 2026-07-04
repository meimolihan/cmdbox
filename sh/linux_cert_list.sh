#!/bin/bash
set -uo pipefail

list_color_init() {
    export gl_hui=$'\033[38;5;59m'
    export gl_hong=$'\033[38;5;9m'
    export gl_lv=$'\033[38;5;10m'
    export gl_huang=$'\033[38;5;11m'
    export gl_lan=$'\033[38;5;32m'
    export gl_bai=$'\033[38;5;15m'
    export gl_zi=$'\033[38;5;13m'
    export gl_bufan=$'\033[38;5;14m'
    export reset=$'\033[0m'
}
list_color_init

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}\c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

column_if_available() {
    if command -v column &> /dev/null; then
        column -t -s $'\t'
    else
        cat
    fi
}

list_beautify_linux_cert() {
    {
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "域名" "颁发者" "创建日期" "到期日期" "剩余天数" "状态" "$reset"
        printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_hui" "--------" "--------" "--------" "--------" "--------" "--------" "$reset"

        local found=0
        local now_epoch
        now_epoch=$(date +%s 2>/dev/null)

        if command -v certbot &> /dev/null && [ -d /etc/letsencrypt/live ]; then
            certbot certificates 2>/dev/null | grep -E "Domains:|Certificate Path:|Expiry Date:" | paste - - - | while IFS= read -r line; do
                domain=$(echo "$line" | grep -oP 'Domains: \K\S+' | sed 's/,//')
                expiry_str=$(echo "$line" | grep -oP 'Expiry Date: \K.+')
                cert_path=$(echo "$line" | grep -oP 'Certificate Path: \K.+')
                [ -z "$domain" ] && domain="--"
                [ -z "$expiry_str" ] && expiry_str="--"

                if [ -n "$expiry_str" ] && [ "$expiry_str" != "--" ]; then
                    expiry_epoch=$(date -d "$expiry_str" +%s 2>/dev/null)
                    if [ -n "$expiry_epoch" ] && [ -n "$now_epoch" ]; then
                        days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
                    else
                        days_left="?"
                    fi
                else
                    days_left="?"
                fi

                if [ "$days_left" = "?" ]; then
                    status_text="未知"
                    status_color="$gl_hui"
                elif [ "$days_left" -lt 0 ]; then
                    status_text="已过期"
                    status_color="$gl_hong"
                elif [ "$days_left" -le 7 ]; then
                    status_text="紧急"
                    status_color="$gl_hong"
                elif [ "$days_left" -le 30 ]; then
                    status_text="即将到期"
                    status_color="$gl_huang"
                else
                    status_text="有效"
                    status_color="$gl_lv"
                fi

                local issuer="Let's Encrypt"
                local created="--"
                if [ -n "$cert_path" ]; then
                    created=$(openssl x509 -in "$cert_path" -noout -startdate 2>/dev/null | cut -d= -f2-)
                fi

                local days_color="$gl_lv"
                if [ "$days_left" != "?" ]; then
                    if [ "$days_left" -lt 0 ]; then
                        days_color="$gl_hong"
                    elif [ "$days_left" -le 7 ]; then
                        days_color="$gl_hong"
                    elif [ "$days_left" -le 30 ]; then
                        days_color="$gl_huang"
                    fi
                fi

                printf "%s%s\t%s%s\t%s%s\t%s%s\t%s%s\t%s%s\n" \
                       "$gl_lan" "$domain$reset" \
                       "$gl_hui" "$issuer$reset" \
                       "$gl_bufan" "$created$reset" \
                       "$gl_huang" "$expiry_str$reset" \
                       "$days_color" "${days_left}d$reset" \
                       "$status_color" "$status_text$reset"
                found=1
            done
        fi

        for cert_dir in /etc/ssl/certs /etc/ssl /etc/letsencrypt/live; do
            [ ! -d "$cert_dir" ] && continue
            while IFS= read -r -d '' cert_file; do
                local domain=""
                local issuer=""
                local created=""
                local expiry=""
                local days_left="?"

                domain=$(openssl x509 -in "$cert_file" -noout -subject 2>/dev/null | sed 's/.*CN = //;s/,.*//')
                issuer=$(openssl x509 -in "$cert_file" -noout -issuer 2>/dev/null | sed 's/.*CN = //;s/,.*//')
                created=$(openssl x509 -in "$cert_file" -noout -startdate 2>/dev/null | cut -d= -f2-)
                expiry=$(openssl x509 -in "$cert_file" -noout -enddate 2>/dev/null | cut -d= -f2-)

                [ -z "$domain" ] && domain="(未知)"
                [ -z "$issuer" ] && issuer="(未知)"
                [ -z "$created" ] && created="--"
                [ -z "$expiry" ] && expiry="--"

                if [ "$expiry" != "--" ]; then
                    expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null)
                    if [ -n "$expiry_epoch" ] && [ -n "$now_epoch" ]; then
                        days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
                    fi
                fi

                local status_text status_color days_color
                if [ "$days_left" = "?" ]; then
                    status_text="未知"
                    status_color="$gl_hui"
                    days_color="$gl_hui"
                elif [ "$days_left" -lt 0 ]; then
                    status_text="已过期"
                    status_color="$gl_hong"
                    days_color="$gl_hong"
                elif [ "$days_left" -le 7 ]; then
                    status_text="紧急"
                    status_color="$gl_hong"
                    days_color="$gl_hong"
                elif [ "$days_left" -le 30 ]; then
                    status_text="即将到期"
                    status_color="$gl_huang"
                    days_color="$gl_huang"
                else
                    status_text="有效"
                    status_color="$gl_lv"
                    days_color="$gl_lv"
                fi

                printf "%s%s\t%s%s\t%s%s\t%s%s\t%s%s\t%s%s\n" \
                       "$gl_lan" "$domain$reset" \
                       "$gl_hui" "$issuer$reset" \
                       "$gl_bufan" "$created$reset" \
                       "$gl_huang" "$expiry$reset" \
                       "$days_color" "${days_left}d$reset" \
                       "$status_color" "$status_text$reset"
                found=1
            done < <(find "$cert_dir" -name "cert.pem" -o -name "fullchain.pem" -o -name "*.crt" 2>/dev/null -print0)
        done

        if [ "$found" -eq 0 ]; then
            printf "%s%s\t%s\t%s\t%s\t%s\t%s%s\n" "$gl_huang" "(无证书)" "(无证书)" "(无证书)" "(无证书)" "(无证书)" "(无证书)" "$reset"
        fi
    } | column_if_available
}

list_beautify_all() {
    clear
    echo -e "${gl_zi}>>> Linux SSL证书列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    list_beautify_linux_cert
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

list_beautify_all

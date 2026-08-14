#!/usr/bin/env bash
# Enable IP forwarding and configure iptables to route traffic from the
# Docker bridge subnet through the AmneziaWG tunnel (tun0).
#
# Usage: sudo bash enable-gateway-routing.sh
# Reverse: sudo bash disable-gateway-routing.sh

set -euo pipefail

TUN_DEV="${TUN_DEV:-tun0}"
DOCKER_BRIDGE_NET="${DOCKER_BRIDGE_NET:-172.20.0.0/24}"

enable() {
    echo "==> Enabling IP forwarding"
    sysctl -w net.ipv4.ip_forward=1

    echo "==> Waiting for ${TUN_DEV} to appear..."
    for i in $(seq 1 30); do
        if ip link show "${TUN_DEV}" &>/dev/null; then
            echo "    ${TUN_DEV} is up"
            break
        fi
        sleep 1
    done

    if ! ip link show "${TUN_DEV}" &>/dev/null; then
        echo "ERROR: ${TUN_DEV} not found. Is the VPN container running?"
        exit 1
    fi

    echo "==> Adding iptables NAT + FORWARD rules"
    iptables -t nat -C POSTROUTING -s "${DOCKER_BRIDGE_NET}" -o "${TUN_DEV}" -j MASQUERADE 2>/dev/null || \
        iptables -t nat -A POSTROUTING -s "${DOCKER_BRIDGE_NET}" -o "${TUN_DEV}" -j MASQUERADE

    iptables -C FORWARD -i "${TUN_DEV}" -j ACCEPT 2>/dev/null || \
        iptables -A FORWARD -i "${TUN_DEV}" -j ACCEPT

    iptables -C FORWARD -o "${TUN_DEV}" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
        iptables -A FORWARD -o "${TUN_DEV}" -m state --state RELATED,ESTABLISHED -j ACCEPT

    echo "==> Gateway routing enabled"
}

disable() {
    echo "==> Removing iptables NAT + FORWARD rules"
    iptables -t nat -D POSTROUTING -s "${DOCKER_BRIDGE_NET}" -o "${TUN_DEV}" -j MASQUERADE 2>/dev/null || true
    iptables -D FORWARD -i "${TUN_DEV}" -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -o "${TUN_DEV}" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
    sysctl -w net.ipv4.ip_forward=0
    echo "==> Gateway routing disabled"
}

case "${1:-enable}" in
    enable)  enable ;;
    disable) disable ;;
    *) echo "Usage: $0 {enable|disable}" >&2; exit 1 ;;
esac

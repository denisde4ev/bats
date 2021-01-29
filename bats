#!/bin/sh

set -eu
IFS='
'

power_supply_path=/sys/class/power_supply

if [ $# -eq 0 ]; then
	set -- "$power_supply_path"/BAT*
	[ ! -d "$1" ] && [ -d "$power_supply_path"/battery ] && set -- "$power_supply_path"/battery # Android
else
	set -- $( printf "$power_supply_path/%s\\n" "$@")
fi

if [ ! -d "$1" ]; then
	printf 'No batteries found in %s\n' "$power_supply_path" >&2
	exit 2
fi

if [ $# = 1 ]; then # on Android else gets wrong values value, also 99.99% of devices are with 1 battery
	printf '%d%s\n' "$(cat "$1/capacity")" "$(cut -c 1 "$1/status")"
	exit $?
fi

sum() {
	local total
	total=0

	for file do
		[ -f "$file" ] && total=$(( total + $(cat "$file") ))
	done
	echo "$total"
}

get_statuses() {
	cut -c 1 $(printf '%s/status\n' "$@") </dev/null | tr -d '\n'
}

charge_full=$(sum \
	$(printf '%s/energy_full\n' "$@") \
	$(printf '%s/charge_full\n' "$@")
)
charge_now=$(sum \
	$(printf '%s/energy_now\n' "$@") \
	$(printf '%s/charge_now\n' "$@")
)
status=$(get_statuses "$@")

# Avoid dividing by zero if charge_full is nonsense
if [ "$charge_full" -le 0 ]; then
	printf 'Your battery max charge value (%s) is <= 0.\n' "$charge_full" >&2
	printf 'Please consider filing a kernel bug for your battery.\n' >&2
	exit 1
fi

charge_percentage=$(( charge_now * 100 / charge_full ))

# Some batteries show values >100 and never "F", or report >100 values :-(
if [ "$charge_percentage" -ge 100 ]; then
	charge_percentage=100
	status=$(printf "%0.sF" "$@")
fi

printf '%d%s\n' "$charge_percentage" "$status"

#!/usr/bin/env bash
# Test -f/filetype per-path semantics  #1242 #573 #2286
source tests/testenv.sh

VDB="$VD --batch"
FAIL=0

check() {
    local desc="$1" expected="$2"
    shift 2
    local result rc
    result=$($VDB "$@" -O -) && rc=$? || rc=$?
    if [[ $rc -ne 0 ]]; then
        echo "FAIL: $desc (vd exited with $rc)"
        FAIL=1
    elif [[ "$result" != "$expected" ]]; then
        echo "FAIL: $desc"
        echo "  expected: '$expected'"
        echo "  got:      '$result'"
        FAIL=1
    fi
}

firstline_check() {
    local desc="$1" expected="$2" outfile="$3"
    local result
    result=$(head -1 "$outfile" | tr -d '\r')
    if [[ "$result" != "$expected" ]]; then
        echo "FAIL: $desc"
        echo "  expected: '$expected'"
        echo "  got:      '$result'"
        FAIL=1
    fi
}

mkdir -p $OUTDIR
rm -f $OUTDIR/ft-*

# CSV content with an uninformative extension
printf 'a,b\n1,2\n3,4\n' > $OUTDIR/ft-data.txt

# === -f forces loader for subsequent paths ===
check "no -f: .txt loads as text" "a,b" $OUTDIR/ft-data.txt
check "-f csv on .txt" "1" -f csv $OUTDIR/ft-data.txt
check '-f "" resets to extension' "a,b" -f csv -f "" $OUTDIR/ft-data.txt

# === -f applies to stdin ===
result=$(printf 'a,b\n1,2\n' | $VDB -f csv - -O -)
if [[ "$result" != "1" ]]; then
    echo "FAIL: -f csv on piped stdin (got '$result')"
    FAIL=1
fi

# === -f applies to -o output path (#1242) ===
$VDB -f csv $OUTDIR/ft-data.txt -o $OUTDIR/ft-out1.txt
firstline_check "-f before -o: output saved as csv" "a,b" $OUTDIR/ft-out1.txt

$VDB -o $OUTDIR/ft-out2.txt -f csv $OUTDIR/ft-data.txt
firstline_check "-o before -f: output saved by extension" $'a\tb' $OUTDIR/ft-out2.txt

# === fallback to save_filetype requires confirm (#2286) ===
if $VDB -o $OUTDIR/ft-out.xyz -f csv $OUTDIR/ft-data.txt 2>/dev/null; then
    echo "FAIL: save to unknown extension should fail in batch mode without -y"
    FAIL=1
fi
if [[ -e $OUTDIR/ft-out.xyz ]]; then
    echo "FAIL: unconfirmed fallback save should not create the file"
    FAIL=1
fi

$VDB -y -o $OUTDIR/ft-out.xyz -f csv $OUTDIR/ft-data.txt
firstline_check "-y accepts fallback to tsv" $'a\tb' $OUTDIR/ft-out.xyz

exit $FAIL




test() {
    echo "Running SEL test"
    echo "" > err.txt
    odin test src/ -out:sel.bin \
        -define:ODIN_TEST_THREADS=1 \
        -define:ODIN_TEST_FANCY=false &> err.txt

    cat err.txt
    # sed -r "s/\x1B\[(([0-9]{1,2})?(;)?([0-9]{1,2})?)?[m,K,H,f,J]//g" err.txt
}


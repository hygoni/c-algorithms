#!/bin/bash

runtime_set_without_plsan=()
runtime_set_with_plsan=()
name1=()
name2=()

CC=$PWD/../build/bin/clang

CC=$CC ./autogen.sh

make clean
make -j$(nproc)
make -j$(nproc) -C src libcalgtest.a

for t in $(ls ./test/test-*.c);
do
  tc=${t%.c}
  tcname=$(basename $tc)
  make -C test $tcname
  echo -n "[$tcname] : "
  start=$(date +%s.%N)
  ./$tc
  end=$(date +%s.%N)
  runtime=$(echo "$end - $start" | bc)
  echo $runtime
  runtime_set_without_plsan+=($runtime)
  name1+=($tcname)
done

echo ${runtime_set_without_plsan[@]}

make clean

rm -rf FlameGraph
git clone https://github.com/brendangregg/FlameGraph

CFLAGS="-g -fno-omit-frame-pointer -fsanitize=precise-leak" CC=$CC ./autogen.sh
make -j$(nproc)
make -j$(nproc) -C src libcalgtest.a

rm -rfv flamegraph flamegraph.zip
mkdir -v flamegraph

for t in $(ls ./test/test-*.c);
do
  tc=${t%.c}
  tcname=$(basename $tc)
  make -C test $tcname
  start=$(date +%s.%N)
  echo -n "[$tcname] : "
  ./$tc
  end=$(date +%s.%N)
  runtime=$(echo "$end - $start" | bc)
  echo $runtime
  runtime_set_with_plsan+=($runtime)
  name2+=($tcname)


  # generate flamegraph
  rm -f $tc.svg
  rm -f perf.data
  perf record -F 1999 -g ./$tc -o - | perf script -i - | ./FlameGraph/stackcollapse-perf.pl | ./FlameGraph/flamegraph.pl > $tc.svg
  mv $tc.svg flamegraph
done
zip -r flamegraph.zip ./flamegraph

rm output
index=1
while [ $index -ne ${#runtime_set_without_plsan[@]} ]; do
    num1=${runtime_set_without_plsan[$index]}
    num2=${runtime_set_with_plsan[$index]}
    echo -n "${name1[$index]} : " >> output
    echo "scale=2 ; $num2 / $num1" | bc >> output
    ((index++))
done

cat output

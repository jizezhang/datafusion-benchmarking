set -e -x
##
# This script runs the datafusion bench.sh script
# Usage
#
# gh_compare_branch.sh <$PR_URL>
# BENCHMARKS="clickbench_1 tpch_mem" gh_compare_branch.sh <$PR_URL>
#
# Example
# https://github.com/apache/datafusion/pull/15466
#
# Uses directories like this
# ~/arrow-datafusion: branch.sh comparison
# ~/arrow-datafusion2: branch
# ~/arrow-datafusion3: main
#
# And then reports the results to a pull request using the gh command line
#
# Install gh
# https://github.com/cli/cli
# https://github.com/cli/cli/releases/download/v2.69.0/gh_2.69.0_linux_amd64.deb
##

# setup python environment
source ~/venv/bin/activate


PR=$1
if [ -z "$PR" ] ; then
    echo "gh_compare_branch.sh <$PR_URL>"
fi

## Benchmarks to run (bench.sh run <BENCHMARK>)
## Default suite is tpch and clickbench
BENCHMARKS=${BENCHMARKS:-"tpch_mem clickbench_partitioned clickbench_extended"}


## Command used to pre-warm (aka precompile) the directories
export CARGO_COMMAND="cargo run --release"

######
# Fetch and checkout the remote branch in datafusion-pr
######

pushd ~/datafusion-pr
git reset --hard
git fetch -p origin
gh pr checkout -f $PR
MERGE_BASE=`git merge-base HEAD origin/main`
BRANCH_BASE=`git rev-parse HEAD`
BRANCH_NAME=`git rev-parse --abbrev-ref HEAD`
cargo clean
rm -rf benchmarks/results/*
popd


######
# checkout main corresponding to place the branch diverges (merge-base)
# in arrow-datafusion3
######

pushd ~/datafusion-main
git reset --hard
git fetch -p origin
git checkout $MERGE_BASE
cargo clean
rm -rf benchmarks/results/*
popd

# create comment saying the benchmarks are running
rm -f /tmp/comment.txt
cat >/tmp/comment.txt <<EOL
🤖 \`$0\` [Benchmark Script](https://github.com/alamb/datafusion-benchmarking/blob/main/gh_compare_branch.sh) Running
`uname -a`
Comparing $BRANCH_NAME ($BRANCH_BASE) to $MERGE_BASE [diff](https://github.com/apache/datafusion/compare/$MERGE_BASE..$BRANCH_BASE) using:  $BENCHMARKS
Results will be posted here when complete
EOL
# Post the comment to the ticket
# gh pr comment -F /tmp/comment.txt $PR
cat /tmp/comment.txt

echo "------------------"
echo "Wait for background pre-compilation to complete..."
echo "------------------"
wait
echo "DONE"


######
# run the benchmark (from the datafusion directory
######
pushd ~/datafusion
# git reset --hard
# git checkout main
# git pull
cargo clean
cd benchmarks

echo "clear old results"
rm -rf results/*

for bench in $BENCHMARKS ; do
    echo "** Creating data if needed **"
    # Temp don't do this for cancellation benchmark
    ./bench.sh data $bench || true
    echo "** Running $bench baseline (merge-base from main)... **"
    export DATAFUSION_DIR=~/datafusion-main
    ./bench.sh run $bench
    ## Run against branch
    echo "** Running $bench branch... **"
    export DATAFUSION_DIR=~/datafusion-pr
    ./bench.sh run $bench

done

## Compare
rm -f /tmp/report.txt
BENCH_BRANCH_NAME=${BRANCH_NAME//\//_} # mind blowing syntax to replace / with _
./bench.sh compare HEAD "${BENCH_BRANCH_NAME}" | tee -a /tmp/report.txt

# Post the results as comment to the PR
REPORT=$(cat /tmp/report.txt)
cat >/tmp/comment.txt <<EOL
🤖: Benchmark completed

<details><summary>Details</summary>
<p>


\`\`\`
$REPORT
\`\`\`


</p>
</details>

EOL
# gh pr comment -F /tmp/comment.txt $PR
cat /tmp/comment.txt

#!/bin/bash
#
# Environment variables that can be set:
#   GEM5_NCORES
#   GEM5_OPT
#   BM_DATASET
#   PARSECDIR

gem5_nCores="${GEM5_NCORES:=4}"

gem5_result_prefix="project/results"
bm_dataset="${BM_DATASET:=simsmall}"
gem5_test_case="${gem5_nCores}-${bm_dataset}-se-fmesi"

# gem5 Settings
gem5_dir="${PWD}"
gem5_opt="${GEM5_OPT:=${gem5_dir}/build/ECE666/gem5.fast}"
gem5_config="configs/example/se.py"

gem5_args="${gem5_dir}/${gem5_config} -n ${gem5_nCores} --ruby"
gem5_exec="${gem5_opt} ${gem5_args}"

# TODO add args for ruby system and

# PARSEC Settings

bm_dir="${PARSECDIR:=${gem5_dir}/../parsec-2.1}"

declare -A bm_type

bm_type["blackscholes"]="apps"
bm_type["bodytrack"]="apps"
bm_type["facesim"]="apps"
bm_type["ferret"]="apps"
bm_type["fluidanimate"]="apps"
bm_type["freqmine"]="apps"
bm_type["raytrace"]="apps"
bm_type["swaptions"]="apps"
bm_type["vips"]="apps"

bm_type["canneal"]="kernels"
bm_type["dedup"]="kernels"
bm_type["streamcluster"]="kernels"
# bm_type+=( ["key2"]=val2 ["key3"]=val3 )

bm_names=(
    #"blackscholes"
    # "streamcluster"
    # "fluidanimate"  # takes time ???, expects NTHREADS to be power of 2
    "freqmine"
    # "raytrace"      # requires n-1 threads

    # "canneal"     # seems to take too long
    # "dedup"         # args not populated
    # "bodytrack"   # error when creating threads
    # "facesim"       # args not populated
    # "ferret"      #fatal msync unimplemented
    # "swaptions"   # run args don't get populated
    # "vips"        #syscall sched_getparam unimplemented
)


mkdir -p "${gem5_dir}/${gem5_result_prefix}/m5out-${gem5_test_case}"

# bm_name="blackscholes"

for bm_name in "${bm_names[@]}"; do

    echo ${bm_name}
    # echo ${bm_type[${bm_name}]}

    bm_subdir="pkgs/${bm_type[${bm_name}]}/${bm_name}"
    bm_build="inst/amd64-linux.gcc.pre" #/bin/${bm_name}"
    bm_NTHREADS=${gem5_nCores}
    if [ bm_name == "raytrace" ]; then
        bm_NTHREADS=$((${gem5_nCores} - 1))
    fi
    # bm_NTHREADS=$((${gem5_nCores} - 1))
    printf "Benchmark Threads = ${bm_NTHREADS} \n"

    # Find .runconf
    NTHREADS="${bm_NTHREADS}"
    bm_runconf="${bm_dir}/${bm_subdir}/parsec/${bm_dataset}.runconf"

    source ${bm_runconf}

    bm_run_exec="${bm_dir}/${bm_subdir}/${bm_build}/${run_exec}"
    run_path="${bm_dir}/${bm_subdir}/run"

    gem5_out_dir="${gem5_dir}/${gem5_result_prefix}/m5out-${gem5_test_case}/${bm_name}"
    rm -rf ${gem5_out_dir}
    mkdir -p ${gem5_out_dir} -v

    # Write Config to file
    cfg_file="${bm_name}.gem5conf"
    cfg_file_path="${gem5_out_dir}/${cfg_file}"
    touch ${cfg_file_path}
    printf "Writing RunConfig to ${cfg_file_path} \n"
    printf "gem5 Run Configuration\n" >> ${cfg_file_path}
    printf "gem5_dir=\"${gem5_dir}\"\n" >> ${cfg_file_path}
    printf "gem5_opt=\"${gem5_opt}\"\n" >> ${cfg_file_path}
    printf "gem5_config=\"${gem5_config}\"\n" >> ${cfg_file_path}
    printf "gem5_nCores=\"${gem5_nCores}\"\n" >> ${cfg_file_path}
    printf "gem5_args=\"${gem5_args}\"\n" >> ${cfg_file_path}

    printf "bm_name=\"${bm_name}\"\n" >> ${cfg_file_path}
    printf "bm_dataset=\"${bm_dataset}\"\n" >> ${cfg_file_path}
    printf "" >> ${cfg_file_path}

    # Write environment config to file
    env_file="env.sh"
    env_file_path="${gem5_out_dir}/${env_file}"
    touch ${env_file_path}
    echo "Writing environment variables to ${env_file_path}"
    # env > ${env_file_path}
    printf "OMP_NUM_THREADS=\"${bm_NTHREADS}\"\n" >> ${env_file_path}


    # EXEC_CMD="${gem5_exec} -n 4 -c  ${bm_run_exec} -o \"${bm_NTHREADS} ${run_path}/in_4K.txt ${run_path}/prices.txt\""
    # echo ${EXEC_CMD}
    # eval ${EXEC_CMD}

    bm_hw_cmd="${bm_dir}/bin/parsecmgmt -a run -p ${bm_name} -i ${bm_dataset} -x pre"
    eval ${bm_hw_cmd} >${gem5_out_dir}/golden.out

    cd ${run_path}


    bm_args="${run_args}"
    # gem5_cmd="${gem5_opt} --debug-flags=ProtocolTrace -d ${gem5_out_dir} ${gem5_args}"
    gem5_cmd="${gem5_opt} -d ${gem5_out_dir} ${gem5_args}"
    exec_cmd="${gem5_cmd} -e ${env_file_path} -c ${bm_run_exec} -o \"${run_args}\""
    echo ${exec_cmd}
    # eval "${exec_cmd}"
    eval "nohup ${exec_cmd} &" >${gem5_out_dir}/nohup.out

    debug_cmd="gdb --args ${gem5_opt} -d ${gem5_out_dir} ${gem5_args} -c ${bm_run_exec} -o \"${run_args}\""
    # echo ${debug_cmd} 
    # eval ${debug_cmd}

done

# echo "Copying results to m5out"
# rm -rf  ${gem5_dir}/m5out/${bm_name} -v
# mkdir  ${gem5_dir}/m5out -v
# mkdir  ${gem5_dir}/m5out/${bm_name} -v
# mv ${run_path}/m5out ${gem5_dir}/m5out/${bm_name}/ -f -v
# mv ${run_path}/*.log ${gem5_dir}/m5out/${bm_name}/ -f -v
echo " .. Done"
echo ""

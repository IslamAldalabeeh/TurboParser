#!/bin/bash

# Root folder where TurboParser is installed.
root_folder="`cd $(dirname $0);cd ..;pwd`"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${root_folder}/deps/local/lib"

# Set options.
language=$1 # Example: "slovene" or "english_proj".
train_algorithm=svm_mira # Training algorithm.
num_epochs=10 #20 # Number of training epochs.
regularization_parameter=$2 #0.001 # The C parameter in MIRA.
train=true
test=true
case_sensitive=false # Distinguish word upper/lower case.
form_cutoff=0 # Cutoff in word occurrence.
lemma_cutoff=0 # Cutoff in lemma occurrence.
#projective=true #false # If true, force single-rooted projective trees.
#model_type=standard # Parts used in the model (subset of "af+cs+gp+as+hb+np+dp+gs+ts").
                    # Some shortcuts are: "standard" (means "af+cs+gp");
                    # "basic" (means "af"); and "full" (means "af+cs+gp+as+hb+gs+ts").
                    # Currently, flags np+dp are not recommended because they
                    # make the parser a lot slower.
delta_encoding=$3
dependency_to_constituency=true

suffix_parser=parser_pruned-true_model-standard.pred
suffix=labeler

# Set path folders.
path_bin=${root_folder} # Folder containing the binary.
path_scripts=${root_folder}/scripts # Folder containing scripts.
path_data=${root_folder}/data/${language} # Folder with the data.
path_models=${root_folder}/models/${language} # Folder where models are stored.
path_results=${root_folder}/results/${language} # Folder for the results.

# Create folders if they don't exist.
mkdir -p ${path_data}
mkdir -p ${path_models}
mkdir -p ${path_results}

# Set file paths. Allow multiple test files.
file_model=${path_models}/${language}_${suffix}.model
file_results=${path_results}/${language}_${suffix}.txt

if [ "$language" == "english_proj" ] || [ "$language" == "english_proj_stanford" ]
then
    file_train_orig=${path_data}/${language}_train.conll.predpos
    files_test_orig[0]=${path_data}/${language}_test.conll
    files_test_orig[1]=${path_data}/${language}_dev.conll
    files_test_orig[2]=${path_data}/${language}_test.conll.predpos
    files_test_orig[3]=${path_data}/${language}_dev.conll.predpos

    file_train=${path_data}/${language}_ftags_train.conll.predpos
    files_test[0]=${path_data}/${language}_ftags_test.conll
    files_test[1]=${path_data}/${language}_ftags_dev.conll
    files_test[2]=${path_data}/${language}_ftags_test.conll.predpos
    files_test[3]=${path_data}/${language}_ftags_dev.conll.predpos

    rm -f file_train
    awk 'NF>0{OFS="\t";NF=10;$4=$5;$5=$5;print}NF==0{print}' ${file_train_orig} \
        > ${file_train}

    for (( i=0; i<${#files_test[*]}; i++ ))
    do
        file_test_orig=${files_test_orig[$i]}
        file_test=${files_test[$i]}
        rm -f file_test
        awk 'NF>0{OFS="\t";NF=10;$4=$5;$5=$5;print}NF==0{print}' ${file_test_orig} \
            > ${file_test}
    done
elif [ "$language" == "english_dep2phrase" ]
then
    file_train=${path_data}/${language}_train.conll.predpos
    files_test[0]=${path_data}/${language}_test.conll
    files_test[1]=${path_data}/${language}_dev.conll
    if ${delta_encoding}
    then
        file_train_transformed=${path_data}/${language}_delta_train.conll.predpos
        files_test_transformed[0]=${path_data}/${language}_delta_test.conll
        files_test_transformed[1]=${path_data}/${language}_delta_dev.conll
    fi

    suffix_parser=predicted

elif [ "$language" == "english" ]
then
    file_train=${path_data}/${language}_train.conll
    files_test[0]=${path_data}/${language}_test.conll
    files_test[1]=${path_data}/${language}_dev.conll
elif [ "$language" == "dutch" ]
then
    file_train=${path_data}/${language}_train.conll
    files_test[0]=${path_data}/${language}_test.conll
else
    # For all languages except english and dutch,
    # replace coarse tags by fine tags.
    file_train_orig=${path_data}/${language}_train.conll
    file_test_orig=${path_data}/${language}_test.conll
    file_train=${path_data}/${language}_ftags_train.conll
    file_test=${path_data}/${language}_ftags_test.conll
    rm -f file_train file_test
    awk 'NF>0{OFS="\t";NF=10;$4=$5;$5=$5;print}NF==0{print}' ${file_train_orig} \
        > ${file_train}
    awk 'NF>0{OFS="\t";NF=10;$4=$5;$5=$5;print}NF==0{print}' ${file_test_orig} \
        > ${file_test}
    files_test[0]=${file_test}
fi

# Obtain a prediction file path for each test file.
for (( i=0; i<${#files_test[*]}; i++ ))
do
    file_test=${files_test[$i]}
    file_prediction=${file_test}.${suffix}.pred
    files_prediction[$i]=${file_prediction}
done


################################################
# Train the parser.
################################################

if $train
then

    if ${delta_encoding}
    then
        python delta_encode_labeling_indices.py ${file_train} > ${file_train_transformed}
        file_train_actual=${file_train_transformed}
    else
        file_train_actual=${file_train}
    fi

    ${path_bin}/TurboDependencyLabeler \
        --train \
        --train_epochs=${num_epochs} \
        --file_model=${file_model} \
        --file_train=${file_train_actual} \
        --form_case_sensitive=${case_sensitive} \
        --form_cutoff=${form_cutoff} \
        --lemma_cutoff=${lemma_cutoff} \
        --train_algorithm=${train_algorithm} \
        --train_regularization_constant=${regularization_parameter} \
        --logtostderr
fi


################################################
# Test the parser.
################################################

if $test
then

    rm -f ${file_results}

    # Test first with oracle backbone dependencies.
    for (( i=0; i<${#files_test[*]}; i++ ))
    do

        if ${delta_encoding}
        then
            # Convert gold to delta encoding.
            #python delta_encode_labeling_indices.py ${files_test[$i]} > ${files_test_transformed[$i]}
            file_test=${files_test_transformed[$i]}
            file_prediction=${file_test}.${suffix}.pred
        else
            file_test=${files_test[$i]}
            file_prediction=${files_prediction[$i]}
        fi

        echo ""
        echo "Testing on ${file_test}..."
        ${path_bin}/TurboDependencyLabeler \
            --test \
            --evaluate \
            --file_model=${file_model} \
            --file_test=${file_test} \
            --file_prediction=${file_prediction} \
            --logtostderr

        if ${delta_encoding}
        then
            # Convert predicted back from delta encoding.
            python delta_encode_labeling_indices.py --from_delta=True ${file_prediction} > ${files_prediction[$i]}
        fi

        echo ""
        echo "Evaluating..."
        touch ${file_results}
        perl ${path_scripts}/eval.pl -b -q -g ${files_test[$i]} -s ${files_prediction[$i]} | tail -5 \
            >> ${file_results}
        cat ${file_results}

        if ${dependency_to_constituency}
        then
            # Convert gold standard file to phrases.
            java -jar -Dfile.encoding=utf-8 converter.jar deconv ${files_test[$i]} ${files_test[$i]}.phrases
            # Convert predicted file to phrases.
            java -jar -Dfile.encoding=utf-8 converter.jar deconv ${files_prediction[$i]} ${files_prediction[$i]}.phrases
            # Run EVALB.
            EVALB/evalb -p EVALB/COLLINS_new.prm ${files_test[$i]}.phrases ${files_prediction[$i]}.phrases | grep Bracketing | head -3 \
                >> ${file_results}
        fi

        cat ${file_results}
    done

    # Now test with predicted backbone dependencies.
    for (( i=0; i<${#files_test[*]}; i++ ))
    do
        if ${delta_encoding}
        then
            # Convert gold to delta encoding.
            file_test=${files_test_transformed[$i]}
            file_test_parsed=${files_test[$i]}.${suffix_parser}
            file_prediction=${file_test}.${suffix}.pred
            #python delta_encode_labeling_indices.py ${files_test[$i]}.${suffix_parser} > ${file_test_parsed}
        else
            file_test=${files_test[$i]}
            file_test_parsed=${file_test}.${suffix_parser}
            file_prediction=${files_prediction[$i]}
        fi

        echo ""
        echo "Testing on ${file_test_parsed}..."
        ${path_bin}/TurboDependencyLabeler \
            --test \
            --evaluate \
            --file_model=${file_model} \
            --file_test=${file_test_parsed} \
            --file_prediction=${file_prediction} \
            --logtostderr

        if ${delta_encoding}
        then
            # Convert back from delta encoding.
            python delta_encode_labeling_indices.py --from_delta=True ${file_prediction} > ${files_prediction[$i]}
        fi

        echo ""
        echo "Evaluating..."
        touch ${file_results}
        perl ${path_scripts}/eval.pl -b -q -g ${files_test[$i]} -s ${files_prediction[$i]} | tail -5 \
            >> ${file_results}

        if ${dependency_to_constituency}
        then
            # Convert gold standard file to phrases.
            java -jar -Dfile.encoding=utf-8 converter.jar deconv ${files_test[$i]} ${files_test[$i]}.phrases
            # Convert predicted file to phrases.
            java -jar -Dfile.encoding=utf-8 converter.jar deconv ${files_prediction[$i]} ${files_prediction[$i]}.phrases
            # Run EVALB.
            EVALB/evalb -p EVALB/COLLINS_new.prm ${files_test[$i]}.phrases ${files_prediction[$i]}.phrases | grep Bracketing | head -3 \
                >> ${file_results}

        fi

        cat ${file_results}
    done
fi

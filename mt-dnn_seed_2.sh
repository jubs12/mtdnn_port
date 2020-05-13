#!/bin/bash

MODEL=$1
TYPE=$2
TASKS=$3
SEED=$4
GRAD_NORM=$5

cd mt-dnn

echo "Preparing train arguments"
INPUT_EN="../data/input/en"
INPUT_PT="../data/input/pt"

PREPRO_BERT_PT="--model neuralmind/bert-$TYPE-portuguese-cased --root_dir $INPUT_PT"
PREPRO_MULTILINGUAL="--model bert-$TYPE-multilingual-cased --root_dir $INPUT_PT"
PREPRO_BERT=" --model bert-$TYPE-uncased --do_lower_case --root_dir $INPUT_EN"

TRAIN_MT_DNN="--init_checkpoint mt_dnn_models/mt_dnn_${TYPE}_uncased.pt \
              --data_dir $INPUT_EN/bert_${TYPE}_uncased_lower"

TRAIN_BERT="--init_checkpoint bert-$TYPE-uncased \
            --data_dir $INPUT_EN/bert_${TYPE}_uncased_lower"

TRAIN_MULTILINGUAL="--data_dir $INPUT_PT/bert_${TYPE}_cased \
                  --init_checkpoint bert-$TYPE-multilingual-cased"

TRAIN_BERT_PT="--data_dir $INPUT_PT/bert_${TYPE}_cased \
               --init_checkpoint neuralmind/bert-$TYPE-portuguese-cased"

if [ "$MODEL" = "bert" ]; then
   PREPRO=$PREPRO_BERT
   TRAIN=$TRAIN_BERT
elif [ "$MODEL" =  "mt-dnn" ]; then
   if [ ! -f "mt_dnn_models/mt_dnn_${TYPE}_uncased.pt" ]; then
      echo "running mt-dnn download script ...wait"
      bash download.sh
   fi
   PREPRO=$PREPRO_BERT
   TRAIN=$TRAIN_MT_DNN
elif [ "$MODEL" = "bert-pt" ]; then
   PREPRO=$PREPRO_BERT_PT
   TRAIN=$TRAIN_BERT_PT
elif [ "$MODEL" = "bert-multilingual" ]; then
   PREPRO=$PREPRO_MULTILINGUAL
   TRAIN=$TRAIN_MULTILINGUAL
else
   echo "invalid option">&2
   exit 127
fi

if [ "$TASKS" = "assin" ]; then
    TASK_LIST=assin-ptbr-sts,assin-ptbr-rte,assin-ptpt-sts,assin2-rte,assin-ptpt-rte,assin2-sts
elif [ "$TASKS" = "assin+tweetsent" ]; then
    TASK_LIST=assin-ptbr-sts,assin-ptbr-rte,assin-ptpt-sts,assin2-rte,assin-ptpt-rte,assin2-sts,tweetsent
elif [ "$TASKS" = "assin2" ]; then
    TASK_LIST=assin2-rte,assin2-sts
elif [ "$TASKS" = "assin-ptbr+assin2" ]; then
    TASK_LIST=assin-ptbr-rte,assin-ptbr-sts,assin2-rte,assin2-sts
else
   echo "invalid option">&2
   exit 127
fi

TASK="--train_datasets $TASK_LIST --test_datasets $TASK_LIST"
TASK_DEF="--task_def ../data/task-def/$TASKS.yaml"
OUTPUT_DIR="../output/mt-dnn_$TASKS/${MODEL}_${TYPE}/seed/$SEED/grad_norm/$GRAD_NORM/"
OUTPUT="--output_dir $OUTPUT_DIR"

rm -rf /root/.cache/torch
python prepro_std.py $PREPRO $TASK_DEF
python train.py $TRAIN $TASK $TASK_DEF $OUTPUT --tensorboard --seed $SEED --fp16 --fp16_opt_level O2  --global_grad_clipping $GRAD_NORM
rm -rf /root/.cache/torch
rm -rf $OUTPUT_DIR/model_*.pt
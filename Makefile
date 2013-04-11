TMP_TRAIN_FOLDER=tmp_train

help:
	@echo "Usage (in order):"
	@echo "make prepare dataset=~/postdoc/datasets/TIMIT"
	@echo "make train dataset_train_folder=~/postdoc/datasets/TIMIT/train"
	@echo "make test dataset_test_folder=~/postdoc/datasets/TIMIT/test"


prepare: wav_config mfcc_and_gammatones.py timit_to_htk_labels.py
	@echo "*** preparing the dataset for phones recognition ***"
	@echo "\n>>> produce MFCC from WAV files\n"
	python mfcc_and_gammatones.py --htk-mfcc $(dataset)/train
	python mfcc_and_gammatones.py --htk-mfcc $(dataset)/test
	@echo "\n>>> transform .phn files into .lab files (frames into nanoseconds)\n"
	python timit_to_htk_labels.py $(dataset)/train
	python timit_to_htk_labels.py $(dataset)/test
	@echo "\n>>> subtitles phones (61 down to 39)\n"
	python substitute_phones.py $(dataset)/train
	python substitute_phones.py $(dataset)/test
	@echo "\n>>> creates (train|test).mlf, (train|test).scp listings and labels (dicts)\n"
	python create_phonesMLF_list_labels.py $(dataset)/train
	python create_phonesMLF_list_labels.py $(dataset)/test


train: train_monophones
	@echo "\n>>> We will only train monophones, see train_triphones make cmd otherwise\n"


train_monophones_monogauss:
	@echo "*** training the HMMs with HTK ***"
	@echo "using folder $(dataset_train_folder)"
	@echo "\n>>> preparing the HMMs\n"
	mkdir $(TMP_TRAIN_FOLDER)
	cp $(dataset_train_folder)/labels $(TMP_TRAIN_FOLDER)/monophones0
	cp $(dataset_train_folder)/train.mlf $(TMP_TRAIN_FOLDER)/
	cp $(dataset_train_folder)/train.scp $(TMP_TRAIN_FOLDER)/
	cp wdnet $(TMP_TRAIN_FOLDER)/
	cp proto.hmm $(TMP_TRAIN_FOLDER)/
	mkdir $(TMP_TRAIN_FOLDER)/hmm_mono_simple0
	mkdir $(TMP_TRAIN_FOLDER)/hmm_mono_simple1
	mkdir $(TMP_TRAIN_FOLDER)/hmm_mono_simple2
	mkdir $(TMP_TRAIN_FOLDER)/hmm_mono_simple3
	# -A -D -T 1 
	HCompV -f 0.001 -m -S $(TMP_TRAIN_FOLDER)/train.scp -M $(TMP_TRAIN_FOLDER)/hmm_mono_simple0 $(TMP_TRAIN_FOLDER)/proto.hmm
	python create_hmmdefs_from_proto.py $(TMP_TRAIN_FOLDER)/hmm_mono_simple0/proto $(TMP_TRAIN_FOLDER)/monophones0 $(TMP_TRAIN_FOLDER)/hmm_mono_simple0/ $(TMP_TRAIN_FOLDER)/hmm_mono_simple0/vFloors
	@echo "\n>>> training the HMMs (3 times)\n"
	HERest -I $(TMP_TRAIN_FOLDER)/train.mlf -S $(TMP_TRAIN_FOLDER)/train.scp -H $(TMP_TRAIN_FOLDER)/hmm_mono_simple0/macros -H $(TMP_TRAIN_FOLDER)/hmm_mono_simple0/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_mono_simple1 $(TMP_TRAIN_FOLDER)/monophones0 
	HERest -I $(TMP_TRAIN_FOLDER)/train.mlf -S $(TMP_TRAIN_FOLDER)/train.scp -H $(TMP_TRAIN_FOLDER)/hmm_mono_simple1/macros -H $(TMP_TRAIN_FOLDER)/hmm_mono_simple1/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_mono_simple2 $(TMP_TRAIN_FOLDER)/monophones0 
	HERest -I $(TMP_TRAIN_FOLDER)/train.mlf -S $(TMP_TRAIN_FOLDER)/train.scp -H $(TMP_TRAIN_FOLDER)/hmm_mono_simple2/macros -H $(TMP_TRAIN_FOLDER)/hmm_mono_simple2/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_mono_simple3 $(TMP_TRAIN_FOLDER)/monophones0 
	cp -r $(TMP_TRAIN_FOLDER)/hmm_mono_simple3 $(TMP_TRAIN_FOLDER)/hmm_final
	cp $(TMP_TRAIN_FOLDER)/monophones0 $(TMP_TRAIN_FOLDER)/phones


add_short_pauses: train_monophones_monogauss
	# TODO incomplete
	python create_short_pause_silence_model.py $(TMP_TRAIN_FOLDER)/hmm3/hmmdefs $(TMP_TRAIN_FOLDER)/hmm4/hmmdefs $(TMP_TRAIN_FOLDER)/monophones1
	#tr "\n" " | " < $(TMP_TRAIN_FOLDER)/monophones1 > $(TMP_TRAIN_FOLDER)/gram
	awk '{if(!$$2) print $$1 " " $$1}' $(TMP_TRAIN_FOLDER)/monophones1 > $(TMP_TRAIN_FOLDER)/dict
	echo "silence sil" >> $(TMP_TRAIN_FOLDER)/dict # why?
	

tweak_silence_model: train_monophones_monogauss
	@echo "\n>>> tweaking the silence model\n"
	mkdir $(TMP_TRAIN_FOLDER)/hmm_mono_silence0
	mkdir $(TMP_TRAIN_FOLDER)/hmm_mono_silence1
	mkdir $(TMP_TRAIN_FOLDER)/hmm_mono_silence2
	mkdir $(TMP_TRAIN_FOLDER)/hmm_mono_silence3
	awk '{if(!$$2) print $$1 " " $$1}' $(TMP_TRAIN_FOLDER)/monophones0 > $(TMP_TRAIN_FOLDER)/dict
	cp $(TMP_TRAIN_FOLDER)/hmm_final/hmmdefs $(TMP_TRAIN_FOLDER)/hmm_mono_silence0/hmmdefs
	cp $(TMP_TRAIN_FOLDER)/hmm_final/macros $(TMP_TRAIN_FOLDER)/hmm_mono_silence0/macros
	HHEd -H $(TMP_TRAIN_FOLDER)/hmm_mono_silence0/macros -H $(TMP_TRAIN_FOLDER)/hmm_mono_silence0/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_mono_silence1 sil.hed $(TMP_TRAIN_FOLDER)/monophones0
	@echo "\n>>> re-training the HMMs\n"
	HERest -I $(TMP_TRAIN_FOLDER)/train.mlf -S $(TMP_TRAIN_FOLDER)/train.scp -H $(TMP_TRAIN_FOLDER)/hmm_mono_silence1/macros -H $(TMP_TRAIN_FOLDER)/hmm_mono_silence1/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_mono_silence2 $(TMP_TRAIN_FOLDER)/monophones0
	HERest -I $(TMP_TRAIN_FOLDER)/train.mlf -S $(TMP_TRAIN_FOLDER)/train.scp -H $(TMP_TRAIN_FOLDER)/hmm_mono_silence2/macros -H $(TMP_TRAIN_FOLDER)/hmm_mono_silence2/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_mono_silence3 $(TMP_TRAIN_FOLDER)/monophones0 
	cp $(TMP_TRAIN_FOLDER)/hmm_mono_silence3/* $(TMP_TRAIN_FOLDER)/hmm_final/


train_monophones: tweak_silence_model
	@echo "\n>>> estimating the number of mixtures\n"
	mkdir $(TMP_TRAIN_FOLDER)/hmm_mono_mix0 # we will loop on these folders as we split
	mkdir $(TMP_TRAIN_FOLDER)/hmm_mono_mix1
	mkdir $(TMP_TRAIN_FOLDER)/hmm_mono_mix2
	mkdir $(TMP_TRAIN_FOLDER)/hmm_mono_mix3
	HERest -s $(TMP_TRAIN_FOLDER)/stats -I $(TMP_TRAIN_FOLDER)/train.mlf -S $(TMP_TRAIN_FOLDER)/train.scp -H $(TMP_TRAIN_FOLDER)/hmm_final/macros -H $(TMP_TRAIN_FOLDER)/hmm_final/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_mono_mix0 $(TMP_TRAIN_FOLDER)/monophones0 
	python create_mixtures_from_stats.py $(TMP_TRAIN_FOLDER)/stats
	@echo "\n--- mixtures of 2 components ---"
	HHed -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix0/hmmdefs $(TMP_TRAIN_FOLDER)/TRMU2.hed $(TMP_TRAIN_FOLDER)/monophones0
	HERest -I $(TMP_TRAIN_FOLDER)/train.mlf -S $(TMP_TRAIN_FOLDER)/train.scp -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix0/macros -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix0/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_mono_mix1 $(TMP_TRAIN_FOLDER)/monophones0
	HERest -I $(TMP_TRAIN_FOLDER)/train.mlf -S $(TMP_TRAIN_FOLDER)/train.scp -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix1/macros -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix1/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_mono_mix2 $(TMP_TRAIN_FOLDER)/monophones0
	HERest -I $(TMP_TRAIN_FOLDER)/train.mlf -S $(TMP_TRAIN_FOLDER)/train.scp -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix2/macros -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix2/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_mono_mix3 $(TMP_TRAIN_FOLDER)/monophones0
	cp $(TMP_TRAIN_FOLDER)/hmm_mono_mix3/* $(TMP_TRAIN_FOLDER)/hmm_mono_mix0/
	@echo "\n--- mixtures of 3 components ---"
	HHed -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix0/hmmdefs $(TMP_TRAIN_FOLDER)/TRMU3.hed $(TMP_TRAIN_FOLDER)/monophones0
	HERest -I $(TMP_TRAIN_FOLDER)/train.mlf -S $(TMP_TRAIN_FOLDER)/train.scp -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix0/macros -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix0/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_mono_mix1 $(TMP_TRAIN_FOLDER)/monophones0
	HERest -I $(TMP_TRAIN_FOLDER)/train.mlf -S $(TMP_TRAIN_FOLDER)/train.scp -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix1/macros -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix1/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_mono_mix2 $(TMP_TRAIN_FOLDER)/monophones0
	HERest -I $(TMP_TRAIN_FOLDER)/train.mlf -S $(TMP_TRAIN_FOLDER)/train.scp -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix2/macros -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix2/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_mono_mix3 $(TMP_TRAIN_FOLDER)/monophones0
	cp $(TMP_TRAIN_FOLDER)/hmm_mono_mix3/* $(TMP_TRAIN_FOLDER)/hmm_mono_mix0/
	@echo "\n--- mixtures of 5 components ---"
	HHed -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix0/hmmdefs $(TMP_TRAIN_FOLDER)/TRMU5.hed $(TMP_TRAIN_FOLDER)/monophones0
	HERest -I $(TMP_TRAIN_FOLDER)/train.mlf -S $(TMP_TRAIN_FOLDER)/train.scp -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix0/macros -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix0/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_mono_mix1 $(TMP_TRAIN_FOLDER)/monophones0
	HERest -I $(TMP_TRAIN_FOLDER)/train.mlf -S $(TMP_TRAIN_FOLDER)/train.scp -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix1/macros -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix1/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_mono_mix2 $(TMP_TRAIN_FOLDER)/monophones0
	HERest -I $(TMP_TRAIN_FOLDER)/train.mlf -S $(TMP_TRAIN_FOLDER)/train.scp -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix2/macros -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix2/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_mono_mix3 $(TMP_TRAIN_FOLDER)/monophones0
	cp $(TMP_TRAIN_FOLDER)/hmm_mono_mix3/* $(TMP_TRAIN_FOLDER)/hmm_mono_mix0/
	@echo "\n--- mixtures of 9 components ---"
	HHed -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix0/hmmdefs $(TMP_TRAIN_FOLDER)/TRMU9.hed $(TMP_TRAIN_FOLDER)/monophones0
	HERest -I $(TMP_TRAIN_FOLDER)/train.mlf -S $(TMP_TRAIN_FOLDER)/train.scp -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix0/macros -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix0/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_mono_mix1 $(TMP_TRAIN_FOLDER)/monophones0
	HERest -I $(TMP_TRAIN_FOLDER)/train.mlf -S $(TMP_TRAIN_FOLDER)/train.scp -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix1/macros -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix1/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_mono_mix2 $(TMP_TRAIN_FOLDER)/monophones0
	HERest -I $(TMP_TRAIN_FOLDER)/train.mlf -S $(TMP_TRAIN_FOLDER)/train.scp -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix2/macros -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix2/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_mono_mix3 $(TMP_TRAIN_FOLDER)/monophones0
	cp $(TMP_TRAIN_FOLDER)/hmm_mono_mix3/* $(TMP_TRAIN_FOLDER)/hmm_mono_mix0/
	@echo "\n--- mixtures of 17 components ---"
	HHed -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix0/hmmdefs $(TMP_TRAIN_FOLDER)/TRMU17.hed $(TMP_TRAIN_FOLDER)/monophones0
	HERest -I $(TMP_TRAIN_FOLDER)/train.mlf -S $(TMP_TRAIN_FOLDER)/train.scp -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix0/macros -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix0/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_mono_mix1 $(TMP_TRAIN_FOLDER)/monophones0
	HERest -I $(TMP_TRAIN_FOLDER)/train.mlf -S $(TMP_TRAIN_FOLDER)/train.scp -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix1/macros -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix1/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_mono_mix2 $(TMP_TRAIN_FOLDER)/monophones0
	HERest -I $(TMP_TRAIN_FOLDER)/train.mlf -S $(TMP_TRAIN_FOLDER)/train.scp -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix2/macros -H $(TMP_TRAIN_FOLDER)/hmm_mono_mix2/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_mono_mix3 $(TMP_TRAIN_FOLDER)/monophones0
	cp $(TMP_TRAIN_FOLDER)/hmm_mono_mix3/* $(TMP_TRAIN_FOLDER)/hmm_final/
	cp $(TMP_TRAIN_FOLDER)/monophones0 $(TMP_TRAIN_FOLDER)/phones



realign: tweak_silence_model
	# TODO check the production of aligned.mlf, and TODO use it for triphones
	@echo "\n>>> re-aligning the training data\n"
	HVite -l '*' -o SWT -b sil -a -H $(TMP_TRAIN_FOLDER)/hmm8/macros -H $(TMP_TRAIN_FOLDER)/hmm8/hmmdefs -i $(TMP_TRAIN_FOLDER)/aligned.mlf -m -t 250.0 -y lab -S $(TMP_TRAIN_FOLDER)/train.scp $(TMP_TRAIN_FOLDER)/dict $(TMP_TRAIN_FOLDER)/monophones0
	mkdir $(TMP_TRAIN_FOLDER)/hmm9
	mkdir $(TMP_TRAIN_FOLDER)/hmm10
	HERest -I $(TMP_TRAIN_FOLDER)/aligned.mlf -S $(TMP_TRAIN_FOLDER)/train.scp -H $(TMP_TRAIN_FOLDER)/hmm8/macros -H $(TMP_TRAIN_FOLDER)/hmm8/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm9 $(TMP_TRAIN_FOLDER)/monophones0 
	HERest -I $(TMP_TRAIN_FOLDER)/aligned.mlf -S $(TMP_TRAIN_FOLDER)/train.scp -H $(TMP_TRAIN_FOLDER)/hmm9/macros -H $(TMP_TRAIN_FOLDER)/hmm9/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm10 $(TMP_TRAIN_FOLDER)/monophones0 
	cp $(TMP_TRAIN_FOLDER)/hmm9/* $(TMP_TRAIN_FOLDER)/hmm_final/


train_untied_triphones: tweak_silence_model
	# TODO use aligned.mlf instead of train.mlf?
	@echo "\n>>> make triphones from monophones\n"
	#HLEd -n $(TMP_TRAIN_FOLDER)/triphones1 -l '*' -i $(TMP_TRAIN_FOLDER)/wintri.mlf mktri.led $(TMP_TRAIN_FOLDER)/aligned.mlf
	HLEd -n $(TMP_TRAIN_FOLDER)/triphones0 -l '*' -i $(TMP_TRAIN_FOLDER)/wintri.mlf mktri.led $(TMP_TRAIN_FOLDER)/train.mlf
	mkdir $(TMP_TRAIN_FOLDER)/hmm_tri_simple0
	mkdir $(TMP_TRAIN_FOLDER)/hmm_tri_simple1
	mkdir $(TMP_TRAIN_FOLDER)/hmm_tri_simple2
	mkdir $(TMP_TRAIN_FOLDER)/hmm_tri_simple3
	maketrihed $(TMP_TRAIN_FOLDER)/monophones0 $(TMP_TRAIN_FOLDER)/triphones0
	HHEd -B -H $(TMP_TRAIN_FOLDER)/hmm_final/macros -H $(TMP_TRAIN_FOLDER)/hmm_final/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_tri_simple0 mktri.hed $(TMP_TRAIN_FOLDER)/monophones0
	HERest -I $(TMP_TRAIN_FOLDER)/wintri.mlf -s $(TMP_TRAIN_FOLDER)/tri_stats -S $(TMP_TRAIN_FOLDER)/train.scp -H $(TMP_TRAIN_FOLDER)/hmm_tri_simple0/macros -H $(TMP_TRAIN_FOLDER)/hmm_tri_simple0/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_tri_simple1 $(TMP_TRAIN_FOLDER)/triphones0 
	HERest -I $(TMP_TRAIN_FOLDER)/wintri.mlf -s $(TMP_TRAIN_FOLDER)/tri_stats -S $(TMP_TRAIN_FOLDER)/train.scp -H $(TMP_TRAIN_FOLDER)/hmm_tri_simple1/macros -H $(TMP_TRAIN_FOLDER)/hmm_tri_simple1/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_tri_simple2 $(TMP_TRAIN_FOLDER)/triphones0 
	HERest -I $(TMP_TRAIN_FOLDER)/wintri.mlf -s $(TMP_TRAIN_FOLDER)/tri_stats -S $(TMP_TRAIN_FOLDER)/train.scp -H $(TMP_TRAIN_FOLDER)/hmm_tri_simple2/macros -H $(TMP_TRAIN_FOLDER)/hmm_tri_simple2/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_tri_simple3 $(TMP_TRAIN_FOLDER)/triphones0 
	cp $(TMP_TRAIN_FOLDER)/hmm_tri_simple3/* $(TMP_TRAIN_FOLDER)/hmm_final/
	cp $(TMP_TRAIN_FOLDER)/triphones0 $(TMP_TRAIN_FOLDER)/phones


train_tied_triphones: train_untied_triphones
	@echo "\n>>> tying triphones\n"
	mkdir $(TMP_TRAIN_FOLDER)/hmm_tri_tied0
	mkdir $(TMP_TRAIN_FOLDER)/hmm_tri_tied1
	mkdir $(TMP_TRAIN_FOLDER)/hmm_tri_tied2
	python adapt_quests.py tmp_train/monophones0 quests_example.hed tmp_train/quests.hed
	# HDMan -n fulllist -l flog dict-tri tmp_train/dict
	cp fulllist tmp_train/fulllist
	mkclscript TB 350.0 tmp_train/monophones0 > tmp_train/tb_contexts.hed
	python create_contexts_tying.py tmp_train/quests.hed tmp_train/tb_contexts.hed tmp_train/tree.hed tmp_train/tri_stats
	HHEd -B -H $(TMP_TRAIN_FOLDER)/hmm_final/macros -H $(TMP_TRAIN_FOLDER)/hmm_final/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_tri_tied0 $(TMP_TRAIN_FOLDER)/tree.hed $(TMP_TRAIN_FOLDER)/triphones0 > $(TMP_TRAIN_FOLDER)/log
	HERest -I $(TMP_TRAIN_FOLDER)/wintri.mlf -s $(TMP_TRAIN_FOLDER)/tri_stats -S $(TMP_TRAIN_FOLDER)/train.scp -H $(TMP_TRAIN_FOLDER)/hmm_tri_tied0/macros -H $(TMP_TRAIN_FOLDER)/hmm_tri_tied0/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_tri_tied1 $(TMP_TRAIN_FOLDER)/triphones0 
	HERest -I $(TMP_TRAIN_FOLDER)/wintri.mlf -s $(TMP_TRAIN_FOLDER)/tri_stats -S $(TMP_TRAIN_FOLDER)/train.scp -H $(TMP_TRAIN_FOLDER)/hmm_tri_tied1/macros -H $(TMP_TRAIN_FOLDER)/hmm_tri_tied1/hmmdefs -M $(TMP_TRAIN_FOLDER)/hmm_tri_tied2 $(TMP_TRAIN_FOLDER)/triphones0 
	cp $(TMP_TRAIN_FOLDER)/hmm_tri_tied2/* $(TMP_TRAIN_FOLDER)/hmm_final/
	cp $(TMP_TRAIN_FOLDER)/triphones0 $(TMP_TRAIN_FOLDER)/phones


train_triphones: train_tied_triphones
	@echo "\n>>> estimating the number of mixtures\n"
	# TODO


test:
	@echo "*** testing the trained model ***"
	HVite -w tmp_train/wdnet -H tmp_train/hmm_final/hmmdefs -i tmp_train/outtrans.mlf -S ~/postdoc/datasets/TIMIT/test/test.scp -o ST tmp_train/dict tmp_train/phones
	HResults -I ~/postdoc/datasets/TIMIT/test/test.mlf tmp_train/phones tmp_train/outtrans.mlf


clean:
	rm -rf $(TMP_TRAIN_FOLDER)

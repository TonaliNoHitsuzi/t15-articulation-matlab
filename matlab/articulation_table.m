function T = articulation_table()
%ARTICULATION_TABLE ARPAbet phoneme -> articulatory feature mapping (MATLAB port)
%   T = articulation_table() returns a struct with fields:
%     phons  : 41x1 cell  LOGIT_TO_PHONEME index -> phoneme symbol
%              (index 1 = 'BLANK', 2..40 = 39 ARPAbet phonemes, 41 = ' | ')
%     manner : 41x1 cell  manner of articulation (6 classes + '')
%     place  : 41x1 cell  place of articulation (8 classes + '')
%   Mapping follows evaluate_model_helpers.LOGIT_TO_PHONEME from
%   nejm-brain-to-text and the hand-labelled Python version
%   articulation_features.py exactly.

phons = { ...
    'BLANK', ...
    'AA','AE','AH','AO','AW','AY','B','CH','D','DH', ...
    'EH','ER','EY','F','G','HH','IH','IY','JH','K', ...
    'L','M','N','NG','OW','OY','P','R','S','SH', ...
    'T','TH','UH','UW','V','W','Y','Z','ZH', ...
    ' | '};

% vowels use tongue position (front/central/back) as place
tab = containers.Map('KeyType','char','ValueType','any');
tab('AA') = {'VOWEL','back'};     tab('AE') = {'VOWEL','front'};
tab('AH') = {'VOWEL','central'};  tab('AO') = {'VOWEL','back'};
tab('AW') = {'VOWEL','back'};     tab('AY') = {'VOWEL','front'};
tab('EH') = {'VOWEL','front'};    tab('ER') = {'VOWEL','central'};
tab('EY') = {'VOWEL','front'};    tab('IH') = {'VOWEL','front'};
tab('IY') = {'VOWEL','front'};    tab('OW') = {'VOWEL','back'};
tab('OY') = {'VOWEL','back'};     tab('UH') = {'VOWEL','back'};
tab('UW') = {'VOWEL','back'};
% stops
tab('B')  = {'STOP','LABIAL'};        tab('P')  = {'STOP','LABIAL'};
tab('D')  = {'STOP','DENTAL_ALV'};    tab('T')  = {'STOP','DENTAL_ALV'};
tab('G')  = {'STOP','VELAR'};         tab('K')  = {'STOP','VELAR'};
% fricatives
tab('F')  = {'FRICATIVE','LABIAL'};       tab('V')  = {'FRICATIVE','LABIAL'};
tab('TH') = {'FRICATIVE','DENTAL_ALV'};   tab('DH') = {'FRICATIVE','DENTAL_ALV'};
tab('S')  = {'FRICATIVE','DENTAL_ALV'};   tab('Z')  = {'FRICATIVE','DENTAL_ALV'};
tab('SH') = {'FRICATIVE','POSTALV_PAL'};  tab('ZH') = {'FRICATIVE','POSTALV_PAL'};
tab('HH') = {'FRICATIVE','GLOTTAL'};
% affricates
tab('CH') = {'AFFRICATE','POSTALV_PAL'};  tab('JH') = {'AFFRICATE','POSTALV_PAL'};
% nasals
tab('M')  = {'NASAL','LABIAL'};
tab('N')  = {'NASAL','DENTAL_ALV'};
tab('NG') = {'NASAL','VELAR'};
% approximants
tab('L')  = {'APPROXIMANT','DENTAL_ALV'};
tab('R')  = {'APPROXIMANT','DENTAL_ALV'};
tab('W')  = {'APPROXIMANT','LABIAL'};
tab('Y')  = {'APPROXIMANT','POSTALV_PAL'};

n = numel(phons);
manner = cell(n,1);  place = cell(n,1);
for i = 1:n
    p = phons{i};
    if isKey(tab, p)
        v = tab(p);
        manner{i} = v{1};
        place{i}  = v{2};
    else
        manner{i} = '';   % BLANK / ' | ' word boundary, excluded
        place{i}  = '';
    end
end

T = struct('phons',{phons}, 'manner',{manner}, 'place',{place});
end

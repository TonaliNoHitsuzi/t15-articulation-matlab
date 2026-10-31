# T15 皮层内神经信号的音素发音特征分类（MATLAB 实现）

> 《生物医学传感检测与仪器》MATLAB 大作业 · 周增飏 20243002066
> 工具箱：**Statistics and Machine Learning Toolbox**（MATLAB R2021b）

对 ALS 受试者 T15 的**皮层内神经信号**（256 电极 × 2 特征 = 512 维，20 ms 分箱）做
**音素发音特征（manner / place of articulation）的分类识别**，并按脑区组分解其可解码性。
本项目是神经科学导论课程作业（Python 版）在 MATLAB 平台的独立重实现。

- 数据：Card et al., *An Accurate and Rapidly Calibrating Speech Neuroprosthesis*, NEJM 2024 的公开数据
  （[Dryad DOI 10.5061/dryad.dncjsxm85](https://doi.org/10.5061/dryad.dncjsxm85)）
- 官方代码：[Neuroprosthetics-Lab/nejm-brain-to-text](https://github.com/Neuroprosthetics-Lab/nejm-brain-to-text)

## 方法管线

```
data_train.hdf5 (45 sessions)
   │  input_features: T×512   seq_class_ids + seq_len
   ▼
音素段切分（BLANK/词边界剔除，时间轴线性均分，段均值）
   │  每音素一段 512 维特征
   ▼
发音特征映射（39 ARPAbet 音素 -> manner 6 类 / place 8 类）
   ▼
8 个脑区组分类（v6 / a4 / 55b / d6v 阵列 × {阈值穿越, spike band power}）
   │  fitcecoc + fitclinear（L2 logistic，balanced 类权重）
   │  3 折按 trial 分组交叉验证 -> out-of-fold 预测
   ▼
balanced accuracy + 1000 次按 trial bootstrap 95% CI
   ▼
热图 ×2 + 条形图 + summary.json
```

## 目录

```
matlab/
  main_t15_analysis.m   % 主入口（数据->分类->出图->存结果）
  load_t15_dataset.m    % HDF5 解析与音素段切分
  articulation_table.m  % ARPAbet -> manner/place 静态映射表
  fit_logreg_oof.m      % 分组 CV 逻辑回归（fitcecoc+fitclinear）
  bootstrap_balacc_ci.m % balanced accuracy 的 trial-bootstrap CI
  plot_results.m        % 出图
  test_synthetic.m      % 合成数据单元测试（无需真实数据）
tools/
  dryad_fetch.py        % Dryad 下载器（自动过 Anubis PoW 反爬）
  get_s3_url.py         % 提取 S3 预签名直链（配合 aria2 多线程）
results/                % 图 + summary（生成物）
报告-LaTeX/             % 课程报告
```

## 复现步骤

1. **环境**：MATLAB R2019b+（实测 R2021b）+ Statistics and Machine Learning Toolbox
2. **数据**：从 Dryad 下载 `t15_copyTask_neuralData.zip`（11.05 GB，可用 `tools/dryad_fetch.py`），
   解压到 `data/hdf5_data_final/`（或新建 `config/data_root.txt`（UTF-8）写入解压路径）
3. **自检**：`matlab -batch "run('matlab/test_synthetic.m')"` —— 全部通过再继续
4. **全量分析**：`matlab -batch "run('matlab/main_t15_analysis.m')"`
   （首次运行解析 HDF5 约 10–20 min，结果缓存为 `results/segments_cache.mat`）

## 结果

全量（45 sessions / 163,599 段 / 8,072 trials，与 Python 版逐位一致）：

| 脑区组 | manner (chance 0.167) | place (chance 0.125) |
|---|---|---|
| v6_TC | 0.227 [0.223, 0.230] | 0.172 [0.170, 0.175] |
| a4_TC | 0.213 [0.210, 0.217] | 0.181 [0.179, 0.184] |
| 55b_TC | 0.217 [0.214, 0.220] | 0.166 [0.164, 0.168] |
| d6v_TC | 0.189 [0.186, 0.192] | 0.147 [0.145, 0.150] |
| **v6_pow** | **0.237 [0.234, 0.240]** | 0.173 [0.171, 0.175] |
| a4_pow | 0.215 [0.212, 0.218] | **0.181 [0.176, 0.181]** |
| 55b_pow | 0.221 [0.218, 0.224] | 0.168 [0.166, 0.170] |
| d6v_pow | 0.189 [0.185, 0.192] | 0.149 [0.147, 0.152] |

三条结论（与 Python 参考版完全一致）：**16 个 CI 下界全部高于随机水平**；**功率特征全面强于阈值穿越**；**腹侧前运动区（v6）最强、背侧区（d6v）最弱**。图：`results/*.png`，明细：`results/summary.json`。

## 与 Python 版的口径差异（诚实声明）

| 项 | Python 版 | 本 MATLAB 版 |
|---|---|---|
| 分类器 | sklearn `LogisticRegression(C=0.5, class_weight='balanced')`（multinomial softmax） | `fitcecoc` + `fitclinear('Learner','logistic','Regularization','ridge','Lambda',1)`（one-vs-one ECOC），balanced 类权重同式 |
| 正则参数 | C=0.5（等价 λ≈1 数量级） | Lambda=1.0 |
| 折划分 | 同种子 shuffle trial 后 i mod 3 | 同逻辑（rng(0)） |
| bootstrap | 1000 次 trial 重采样 | 同（seed=1） |

## 引用

```bibtex
@article{card2024accurate,
  title={An accurate and rapidly calibrating speech neuroprosthesis},
  author={Card, Nicholas S and Wairagkar, Maitreyee and Iacobacci, Carrina and others},
  journal={New England Journal of Medicine},
  volume={391}, number={4}, pages={365--373},
  year={2024},
  doi={10.1056/NEJMoa2314132}
}
```

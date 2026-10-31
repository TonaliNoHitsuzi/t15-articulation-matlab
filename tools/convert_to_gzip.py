# convert_to_gzip.py -- rewrite LZF-compressed T15 HDF5 files as gzip (MATLAB-native)
# Reads  data/<session>/data_train.hdf5   (lzf filter, h5py-only)
# Writes data_gzip/<session>/data_train.hdf5 (gzip level 1, MATLAB h5read native)
# Datasets copied: input_features, seq_class_ids; attrs: seq_len (all MATLAB needs).
# Usage: python convert_to_gzip.py <src_root> <dst_root> [nproc]
import os
import sys
import time
from multiprocessing import Pool

import h5py


def convert_one(args):
    src_dir, dst_dir = args
    src = os.path.join(src_dir, "data_train.hdf5")
    dst = os.path.join(dst_dir, "data_train.hdf5")
    os.makedirs(dst_dir, exist_ok=True)
    if os.path.exists(dst):
        return (src_dir, "skip")
    t0 = time.time()
    n = 0
    shapes = {}
    with h5py.File(src, "r") as fin, h5py.File(dst, "w") as fout:
        for key in fin.keys():
            g_in = fin[key]
            g_out = fout.create_group(key)
            for ds_name in ("input_features", "seq_class_ids"):
                arr = g_in[ds_name][:]
                g_out.create_dataset(ds_name, data=arr, compression="gzip",
                                     compression_opts=1)
                shapes[ds_name] = arr.shape
            g_out.attrs["seq_len"] = int(g_in.attrs["seq_len"])
            g_out.attrs["n_time_steps"] = int(g_in.attrs["n_time_steps"])
            n += 1
    return (src_dir, f"{n} trials, X={shapes['input_features']}, "
                     f"{time.time()-t0:.0f}s")


def main():
    src_root, dst_root = sys.argv[1], sys.argv[2]
    nproc = int(sys.argv[3]) if len(sys.argv) > 3 else 4
    sessions = sorted(d for d in os.listdir(src_root)
                      if os.path.isdir(os.path.join(src_root, d)))
    jobs = [(os.path.join(src_root, s), os.path.join(dst_root, s))
            for s in sessions]
    print(f"[convert] {len(jobs)} sessions -> {dst_root} ({nproc} proc)", flush=True)
    t0 = time.time()
    with Pool(nproc) as pool:
        for i, (sname, msg) in enumerate(pool.imap_unordered(convert_one, jobs)):
            print(f"  [{i+1:2d}/{len(jobs)}] {os.path.basename(sname)}: {msg} "
                  f"(total {time.time()-t0:.0f}s)", flush=True)
    print(f"[convert] done in {time.time()-t0:.0f}s", flush=True)


if __name__ == "__main__":
    main()

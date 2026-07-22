import json
import glob
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

# 读取结果
json_files = sorted(glob.glob("results/sim-*.results.json"))
data = []
for f in json_files:
    with open(f) as fp:
        d = json.load(fp)
    row = {
        "sim_id": d.get("sim_id"),
        "config": d.get("config_file", "").split("/")[-1],
        "dust_flux": d.get("parameters", {}).get("dust", 0),
        "lithology": d.get("parameters", {}).get("lith", 0),
        "fidelity": d.get("parameters", {}).get("fidel", 0),
        "tri_net": d.get("triangular_network_score", 0),
        "reproduced": d.get("network_reproduced", False),
    }
    # 添加预测值
    pred = d.get("predictions", {})
    for k, v in pred.items():
        row[f"pred_{k}"] = v
    data.append(row)

df = pd.DataFrame(data)
df["reproduced"] = df["reproduced"].astype(bool)

# 保存 CSV
df.to_csv("results_summary.csv", index=False)
print("✅ 汇总 CSV 已保存: results_summary.csv")
print(df[["sim_id", "config", "dust_flux", "tri_net", "reproduced"]].to_string(index=False))

# 绘图
sns.set_style("whitegrid")
fig, axes = plt.subplots(1, 2, figsize=(12, 5))

# TriNet 条形图
bars1 = axes[0].bar(df["sim_id"], df["tri_net"], color=df["reproduced"].map({True: "green", False: "red"}))
axes[0].set_xlabel("Simulation ID")
axes[0].set_ylabel("Triangular Network Score")
axes[0].set_title("TriNet Score per Simulation")
axes[0].set_ylim(0, 1.1)
for bar, val in zip(bars1, df["tri_net"]):
    axes[0].text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.02, f"{val:.2f}", ha="center", va="bottom")

# Signal (dust_flux) 条形图
bars2 = axes[1].bar(df["sim_id"], df["dust_flux"], color="skyblue")
axes[1].set_xlabel("Simulation ID")
axes[1].set_ylabel("Dust Flux Signal")
axes[1].set_title("Signal Strength per Simulation")
for bar, val in zip(bars2, df["dust_flux"]):
    axes[1].text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.02, f"{val:.3f}", ha="center", va="bottom")

plt.tight_layout()
plt.savefig("results_comparison.png", dpi=150)
print("✅ 图表已保存: results_comparison.png")
# 在终端显示图表（如果支持）
plt.show()

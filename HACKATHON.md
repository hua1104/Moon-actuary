# MoonBit 黑客松提交说明

## 一句话介绍

moonactuary 是一个使用 MoonBit 从零实现的中国寿险精算引擎：内置六张 CL(2010-2013) 经验生命表，可计算生存函数、保费与准备金，并通过三条独立准备金路径自动交叉校核。

## 为什么值得评审关注

- **真实行业问题**：将公开但缺少可复用实现的中国寿险经验生命表封装为可调用的 MoonBit 库。
- **结果可以自证**：前瞻法、后顾法、Fackler 递推逐年对照，并扫描第一原则恒等式。
- **MoonBit 多后端**：同一份代码构建到 wasm、wasm-gc、JavaScript 和 native。
- **零第三方依赖**：精算计算、命令行输出和 SVG 绘图均只使用 MoonBit 标准库。
- **可复现交付**：库、CLI、快速样例、62 项测试和 CI 都在同一个仓库中。

## 评审快速复现

```bash
moon run cmd/main verify
moon run cmd/main demo
moon run examples/quickstart
```

`verify` 覆盖 6 张表 × 3 档利率 × 3 类产品，执行 126 项恒等式校核和 1,134 项准备金比对；成功时以 `PASS` 结束。

完整工程验收：

```bash
moon info
moon fmt --check
moon check --target all
moon build --target all
moon test --target all
```

## 两分钟演示路线

1. 用 `moon run cmd/main tables` 展示六张中国经验生命表。
2. 用 `moon run cmd/main premium --product endowment --age 30 --term 20 --rate 2.5` 现场计算保费。
3. 用 `moon run cmd/main compare --product term --age 40 --term 10 --rate 3.5` 对比六张表。
4. 用 `moon run cmd/main reserve --term 5` 展示三种准备金方法逐年完全一致。
5. 用 `moon run cmd/main plot --kind mortality > qx.svg` 展示 MoonBit 零依赖 SVG 绘图。
6. 最后运行 `moon run cmd/main verify`，以自动化 `PASS` 作为结论。

## 关键验收数字

- CL1：`l0 / d0 / L0 / T0 / e0 = 1000000 / 867 / 999567 / 76420142 / 76.42`。
- 30 岁、20 年两全保险、2.5%：趸缴纯保费 `0.614601`，年缴均衡纯保费 `0.038895`。
- 第 20 年末两全保险准备金为 `1.000000`，等于满期给付额。
- 自动验收的恒等式最大残差和准备金最大偏差均显示为 `0.000000000000`。

## 项目边界

当前版本定位为净保费与净保费准备金教学/研究引擎，不包含费用、退保率、分红或监管偿付能力现金流。项目不提供保险销售建议，计算结果应由具备资质的精算专业人员结合具体产品条款使用。

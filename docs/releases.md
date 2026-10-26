# 版本发布与备份

项目使用独立的版本号，不与 Omarchy 的系统版本号绑定。`VERSION` 记录当前源码版本，Git 标签使用 `v` 前缀，例如 `v0.2.0`。

## 编号规则

- 修复问题或少量翻译修正：增加补丁版本，例如 `0.2.1`。
- 扩展汉化范围或增加功能：增加次版本，例如 `0.3.0`。
- 有意引入不兼容改动时，明确说明升级与卸载方式；达到稳定接口后再考虑 `1.0.0`。

## 发布流程

1. 将已完成的 PR 合并到主分支；运行 `./tests/smoke.sh` 并检查 CI。
2. 更新 `VERSION`、中英文 README 的版本信息及兼容性说明。
3. 把 CHANGELOG 的「未发布」条目移到新版本下，填写实际发布日期。
4. 提交这些改动后，为确定的提交创建带注释标签，并推送该标签。
5. 创建 GitHub Release，记录变化、验证环境和已知限制。不要把源码兼容检查写成实机验证。
6. 附上由标签生成的源码压缩包及 SHA-256 校验文件。压缩包不要反复提交进 Git 仓库。

已发布标签应保持不变；需要修复时发布新的补丁版本。历史 `v0.1.0` 标签指向首次发布提交 `8b8e8c0`，其原始日期为 2026-08-20；补建 Release 的日期与原始代码发布日期不同。

## 源码与历史备份

Git 标签可随时定位历史版本，GitHub Release 也提供对应源码下载。离线完整历史可另外导出：

```bash
git fetch origin --tags
git bundle create omarchy-zh-cn-history.bundle --all
git bundle verify omarchy-zh-cn-history.bundle
```

`--all` 包含本地可见的提交、分支和标签，不包含未提交文件、GitHub Issue/PR 讨论、Release 附件或 LFS 对象数据。备份应另存到其他硬盘或备份存储；与工作副本放在同一块硬盘上只算本地副本。

可通过克隆恢复并验证：

```bash
git clone -b main omarchy-zh-cn-history.bundle restored-repository
git -C restored-repository fsck --full
```

源码包和完整历史备份用途不同：源码包适合安装某个版本，bundle 适合恢复 Git 历史。

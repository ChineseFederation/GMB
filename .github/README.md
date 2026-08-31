# GitHub 工作流入口

GitHub 只发现 `.github/workflows` 目录中的工作流，因此本仓库固定只保留：

- `workflows/repository.yml`：接收 `push` 与编程控制台调度，传递规范流程身份。
- `workflows/flow.yml`：选择 Runner 并调用 `/Users/rhett/Only/programconsole/flows` 中的中央流程。

禁止在 `.github` 增加产品级 Workflow、脚本副本、测试目录或产品编译、签名、打包实现。

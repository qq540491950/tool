# packages.psd1
# 唯一包列表。每个条目 = 一个 hashtable。
# 必填: name, type
# type 决定内置默认命令；以下字段可覆盖内置默认：
#   check      检查本地版本（省略则只判断'已安装/未安装'）
#   install    安装命令
#   update     升级命令
#   latest     远端版本查询（可选；与 check 输出比对，省略则不比对）
#
# 合法 type：npm / pwsh-module / pwsh-script / binary / scoop / winget / cargo
#
# 注意：以下实配置是你日常管理的包（npm / binary 混合）。
#       其他 5 种 type 的示例块保留在下方供查阅，未启用。

@{
    packages = @(

        # === 你的实配置：npm 全局包（仅需 name + type） ===
        @{ name = '@openai/codex';              type = 'npm' }
        @{ name = '@tencent-ai/codebuddy-code'; type = 'npm' }
        @{ name = 'opencode-ai';               type = 'npm' }
        # @{ name = '@oh-my-pi/pi-coding-agent'; type = 'npm' }
        # @{ name = '@anthropic-ai/claude-code'; type = 'npm' }
        @{ name = '@colbymchenry/codegraph';   type = 'npm' }
        @{ name = 'ccstatusline-zh';           type = 'npm' }

        # ============================================================
        # === 以下为各 type 的注释示例，按需取消注释并修改 ===========
        # ============================================================

        # --- type=pwsh-module 示例：PowerShell Gallery 模块 ---
        # @{ name = 'Terminal-Icons'; type = 'pwsh-module' }

        # --- type=pwsh-script 示例：PowerShell Gallery 脚本 ---
        # @{ name = 'PSFzf'; type = 'pwsh-script' }

        # --- type=binary 示例：自维护二进制（install/update 必填） ---
        @{
            name      = 'omp'
            type      = 'binary'
            check     = 'omp --version'
            install   = 'irm https://omp.sh/install.ps1 | iex'
            update    = 'omp update'
        }

        @{
            name      = 'claude'
            type      = 'binary'
            check     = 'claude --version'
            install   = 'irm https://claude.ai/install.ps1 | iex'
            update    = 'claude update'
        }

        # --- type=scoop 示例 ---
        # @{ name = 'wget'; type = 'scoop' }

        # --- type=winget 示例 ---
        # @{ name = 'GitHub.cli'; type = 'winget' }

        # --- type=cargo 示例 ---
        # @{ name = 'ripgrep'; type = 'cargo' }
    )
}

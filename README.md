# competitest.nvim

<h2 align="center">Competitive Programming with Neovim made Easy</h2>

![competitest](https://user-images.githubusercontent.com/88047141/149839002-280069e5-0c71-4aec-8e39-4443a1c44f5c.png)
<!-- ![competitest](https://user-images.githubusercontent.com/88047141/147982101-2576e960-372c-4dec-b65e-97191c23a57d.png) -->

`competitest.nvim` is a testcase manager and checker. It lets you save time in competitive programming contests by automating common tasks related to testcase management. It can compile, run and test your solutions across all the available testcases, displaying results in a nice interactive user interface.

## Features
- Multiple languages supported: it works out of the box with C, C++, Rust, Java and Python, but other languages can be [configured](#customize-compile-and-run-commands)
- Flexible. No fixed folder structure or strict file-naming rules. You can choose where to put the source code file, the testcases, where to execute your programs and many more
- Configurable (see [Configuration](#configuration)). You can even configure [every folder individually](#local-configuration)
- [Add](#add-or-edit-a-testcase) testcases with `:CompetiTestAdd`
- [Edit](#add-or-edit-a-testcase) a testcases with `:CompetiTestEdit`
- [Delete](#remove-a-testcase) a testcase with `:CompetiTestDelete`
- [Run](#run-testcases) your program across all the testcases with `:CompetiTestRun`, showing results and execution data in a nice interactive window
- Customizable highlight groups. See [Highlights](#highlights)

## Installation
**NOTE:** this plugins requires Neovim ≥ 0.5

Install with `vim-plug`:
``` vim
Plug 'MunifTanjim/nui.nvim'        " it's a dependency
Plug 'xeluxee/competitest.nvim'
```

Install with `packer.nvim`:
``` lua
use {
	'xeluxee/competitest.nvim',
	requires = 'MunifTanjim/nui.nvim',
	config = function() require'competitest'.setup() end
}
```
If you are using another package manager note that this plugin depends on [`nui.nvim`](https://github.com/MunifTanjim/nui.nvim), hence it should be installed as a dependency.

## Usage
To load this plugin call `setup()`:
``` lua
require('competitest').setup() -- to use default configuration
```
``` lua
require('competitest').setup { -- to customize settings
	-- put here configuration
}
```
To see all the available settings see [configuration](#configuration).

### Usage notes
- Your programs must read from `stdin` and print to `stdout`. If `stderr` is used its content will be displayed
- Testcases are stored in text files. A testcase is made by an input file and an output file (containing the correct answer)
- An input file is necessary for a testcase to be considered, while an output file hasn't to be provided necessarily
- Files naming shall follow a rule to be recognized. Let's say your file is called `task-A.cpp`. If using the default configuration testcases associated with that file will be named `task-A_input0.txt`, `task-A_output0.txt`, `task-A_input1.txt`, `task-A_output1.txt` and so on. The counting starts from 0.\
Of course files naming can be configured: see `testcases_files_format` in [configuration](#configuration)
- Testcase files can be put in the same folder of the source code file, but you can customize testcases path (see `testcases_directory` in [configuration](#configuration)).

Anyway you can forget about these rules if you use `:CompetiTestAdd` and `:CompetiTestEdit`, that handle these things for you.

When launching the following commands make sure the focused buffer is the one containing the source code file.

### Add or Edit a testcase
Launch `:CompetiTestAdd` to add a new testcase.\
Launch `:CompetiTestEdit` to edit an existing testcase. If you want to specify testcase number directly in the command line you can use `:CompetiTestEdit x`, where `x` is a number representing the testcase you want to edit.

To jump between input and output windows press either `<C-h>`, `<C-l>`, or `<C-i>`. To save and close testcase editor press `<C-s>`.

Of course these keybindings can be customized: see `editor_ui` ➤ `normal_mode_mappings` and `editor_ui` ➤ `insert_mode_mappings` in [configuration](#configuration)

### Remove a testcase
Launch `:CompetiTestDelete`. If you want to specify testcase number directly in the command line you can use `:CompetiTestDelete x`, where `x` is a number representing the testcase you want to remove.

### Run testcases
Launch `:CompetiTestRun`. CompetiTest's interface will appear and you'll be able to view details about a testcase by moving the cursor over its entry. You can close the UI by pressing `q` or `Q`.\
If you're using a compiled language and you don't want to recompile your program launch `:CompetiTestRunNC`, where "NC" means "No Compile".\
If you have previously closed the UI and you want to re-open it without re-executing testcases or recompiling launch `:CompetiTestRunNE`, where "NE" means "No Execute".

#### Control processes
- Run again a testcase by pressing `R`
- Run again all testcases by pressing `<C-r>`
- Kill the process associated with a testcase by pressing `K`
- Kill all the processes associated with testcases by pressing `<C-k>`

#### View details
- View input in a bigger window by pressing `i` or `I`
- View expected output in a bigger window by pressing `a` or `A`
- View stdout in a bigger window by pressing `o` or `O`
- View stderr in a bigger window by pressing `e` or `E`

Of course all these keybindings can be customized: see `runner_ui` ➤ `mappings` in [configuration](#configuration)

## Configuration
### Full configuration
Here you can find CompetiTest default configuration
``` lua
require('competitest').setup {
	local_config_file_name = ".competitest.lua",

	floating_border = "rounded",
	floating_border_highlight = "FloatBorder",
	picker_ui = {
		width = 0.2,
		height = 0.3,
		mappings = {
			focus_next = { "j", "<down>", "<Tab>" },
			focus_prev = { "k", "<up>", "<S-Tab>" },
			close = { "<esc>", "<C-c>", "q", "Q" },
			submit = { "<cr>" },
		},
	},
	editor_ui = {
		popup_width = 0.4,
		popup_height = 0.6,
		show_nu = true,
		show_rnu = false,
		normal_mode_mappings = {
			switch_window = { "<C-h>", "<C-l>", "<C-i>" },
			save_and_close = "<C-s>",
			cancel = { "q", "Q" },
		},
		insert_mode_mappings = {
			switch_window = { "<C-h>", "<C-l>", "<C-i>" },
			save_and_close = "<C-s>",
			cancel = "<C-q>",
		},
	},
	runner_ui = {
		total_width = 0.8,
		total_height = 0.8,
		selector_width = 0.3,
		selector_show_nu = false,
		selector_show_rnu = false,
		show_nu = true,
		show_rnu = false,
		mappings = {
			run_again = "R",
			run_all_again = "<C-r>",
			kill = "K",
			kill_all = "<C-k>",
			view_input = { "i", "I" },
			view_output = { "a", "A" },
			view_stdout = { "o", "O" },
			view_stderr = { "e", "E" },
			close = { "q", "Q" },
		},
		viewer = {
			width = 0.5,
			height = 0.5,
			show_nu = true,
			show_rnu = false,
			close_mappings = { "q", "Q" },
		},
	},

	save_current_file = true,
	save_all_files = false,
	compile_directory = ".",
	compile_command = {
		c = { exec = "gcc", args = { "-Wall", "$(FNAME)", "-o", "$(FNOEXT)" } },
		cpp = { exec = "g++", args = { "-Wall", "$(FNAME)", "-o", "$(FNOEXT)" } },
		rust = { exec = "rustc", args = { "$(FNAME)" } },
		java = { exec = "javac", args = { "$(FNAME)" } },
	},
	running_directory = ".",
	run_command = {
		c = { exec = "./$(FNOEXT)" },
		cpp = { exec = "./$(FNOEXT)" },
		rust = { exec = "./$(FNOEXT)" },
		python = { exec = "python", args = { "$(FNAME)" } },
		java = { exec = "java", args = { "$(FNOEXT)" } },
	},
	multiple_testing = -1,
	maximum_time = 5000,

	testcases_directory = ".",
	input_name = "input",
	output_name = "output",
	testcases_files_format = "$(FNOEXT)_$(INOUT)$(TCNUM).txt",
	testcases_compare_method = "squish",
}
```

#### Explanation
- `local_config_file_name`: you can use a different configuration for every different folder. See [local configuration](#local-configuration)
- `floating_border`: for details see [here](https://github.com/MunifTanjim/nui.nvim/tree/main/lua/nui/popup#borderstyle)
- `floating_border_highlight`: the highlight group used for popups border
- `picker_ui`: settings related to the testcase picker
	- `width`: a value from 0 to 1, representing the ratio between picker width and Neovim width
	- `height`: a value from 0 to 1, representing the ratio between picker height and Neovim height
	- `mappings`: keyboard mappings to interact with picker
- `editor_ui`: settings related to the testcase editor
	- `popup_width`: a value from 0 to 1, representing the ratio between editor width and Neovim width
	- `popup_height`: a value from 0 to 1, representing the ratio between editor height and Neovim height
	- `show_nu`: whether to show line numbers or not
	- `show_rnu`: whether to show relative line numbers or not
	- `switch_window`: keyboard mappings to switch between input window and output window
	- `save_and_close`: keyboard mappings to save testcase content
	- `cancel`: keyboard mappings to quit testcase editor without saving
- `runner_ui`: settings related to testcase runner user interface
	- `total_width`: a value from 0 to 1, representing the ratio between total runner width and Neovim width
	- `total_height`: a value from 0 to 1, representing the ratio between total runner height and Neovim height
	- `selector_width`: a value from 0 to 1, representing the ratio between testcase selector popup width and the total width
	- `selector_show_nu`: whether to show line numbers or not in testcase selector
	- `selector_show_rnu`: whether to show relative line numbers or not in testcase selector
	- `show_nu`: whether to show line numbers or not in details popups
	- `show_rnu`: whether to show relative line numbers or not in details popups
	- `mappings`: keyboard mappings used in testcase selector popup
		- `run_again`: keymaps to run again a testcase
		- `run_all_again`: keymaps to run again all testcases
		- `kill`: keymaps to kill a testcase
		- `kill_all`: keymaps to kill all testcases
		- `view_input`: keymaps to view input (stdin) in a bigger window
		- `view_output`: keymaps to view expected output in a bigger window
		- `view_stdout`: keymaps to view programs's output (stdout) in a bigger window
		- `view_stderr`: keymaps to view programs's errors (stderr) in a bigger window
		- `close`: keymaps to close runner user interface
	- `viewer`: keyboard mappings used in [viewer window](#view-details)
		- `width`: a value from 0 to 1, representing the ratio between viewer window width and Neovim width
		- `height`: a value from 0 to 1, representing the ratio between viewer window height and Neovim height
		- `show_nu`: whether to show line numbers or not in viewer window
		- `show_rnu`: whether to show relative line numbers or not in viewer window
		- `close_mappings`: keymaps to close viewer window
- `save_current_file`: if true save current file before running testcases
- `save_all_files`: if true save all the opened files before running testcases
- `compile_directory`: execution directory of compiler, relatively to current file's path
- `compile_command`: configure the command used to compile code for every different language, see [here](#customize-compile-and-run-commands)
- `running_directory`: execution directory of your solutions, relatively to current file's path
- `run_command`: configure the command used to run your solutions for every different language, see [here](#customize-compile-and-run-commands)

- `multiple_testing`: how many testcases to run at the same time
	- set it to `-1` if you want to run as many testcases as the number of available CPU cores at the same time
	- set it to `0` if you want to run all the testcases together
	- set it to any positive integer to run that number of testcases contemporarily
- `maximum_time`: maximum time, in milliseconds, given to processes. If it's exceeded process will be killed
- `testcases_directory`: where testcases files are located, relatively to current file's path
- `input_name`: the string substituted to `$(INOUT)` (see [modifiers](#available-modifiers)), used to name input files
- `output_name`: the string substituted to `$(INOUT)` (see [modifiers](#available-modifiers)), used to name output files
- `testcases_files_format`: string representing how testcases files should be named (see [modifiers](#available-modifiers))
- `testcases_compare_method`: how given output (stdout) and expected output should be compared. It can be a string, representing the method to use, or a custom function. Available options follows:
	- `"exact"`: character by character comparison
	- `"squish"`: compare stripping extra white spaces and newlines
	- custom function: you can use a function accepting two arguments, two strings representing output and expected output. It should return true if the given output is acceptable, false otherwise. Example:
		``` lua
		require('competitest').setup {
			testcases_compare_method = function(output, expected_output)
				if output == expected_output then
					return true
				else
					return false
				end
			end
		}
		```

### Local configuration
You can use a different configuration for every different folder by creating a file called `.competitest.lua` (this name can be changed configuring the option `local_config_file_name`). It will affect every file contained in that folder and in subfolders. A table containing valid options must be returned, see the following example.
``` lua
-- .competitest.lua content
return {
	multiple_testing = 3,
	maximum_time = 2500,
	input_name = 'in',
	output_name = 'ans',
	testcases_files_format = "$(INOUT)$(TCNUM).txt",
}
```

### Available modifiers
Modifiers are strings that will be replaced by something else. You can use them to [define commands](#customize-compile-and-run-commands) or to customize `testcases_files_format`.

| Modifier      | Meaning |
| --------      | ------- |
| `$()`         | insert a dollar |
| `$(HOME)`     | user home directory |
| `$(FNAME)`    | file name |
| `$(FNOEXT)`   | file name without extension |
| `$(FEXT)`     | file extension |
| `$(FTYPE)`    | file type |
| `$(FABSPATH)` | absolute path of current file |
| `$(FRELPATH)` | file path, relative to Neovim's current working directory |
| `$(ABSDIR)`   | absolute path of folder that contains file |
| `$(RELDIR)`   | path of folder that contains file, relative to Neovim's current working directory |
| `$(TCNUM)`    | testcase number |
| `$(INOUT)`    | it's substituted with `input_name` or `output_name` (see [configuration](#explanation)), to distinguish testcases input files from testcases output files |

### Customize compile and run commands
Languages as C, C++, Rust, Java and Python are supported by default.\
Of course you can customize commands used for compiling and for running your programs. You can also add languages that aren't supported by default.
``` lua
require('competitest').setup {
	compile_command = {
		cpp       = { exec = 'g++',           args = {'$(FNAME)', '-o', '$(FNOEXT)'} },
		some_lang = { exec = 'some_compiler', args = {'$(FNAME)'} },
	},
	run_command = {
		cpp       = { exec = './$(FNOEXT)' },
		some_lang = { exec = 'some_interpreter', args = {'$(FNAME)'} },
	},
}
```
See [available modifiers](#available-modifiers) to understand better how dollar notation works.

**NOTE:** if your language isn't compiled you can ignore `compile_command` section.

Feel free to open a PR or an issue if you think it's worth adding a new language among default ones.

## Highlights
You can customize CompetiTest highlight groups. Their default values are:
``` vim
hi CompetiTestRunning cterm=bold     gui=bold
hi CompetiTestDone    cterm=none     gui=none
hi CompetiTestCorrect ctermfg=green  guifg=#00ff00
hi CompetiTestWarning ctermfg=yellow guifg=orange
hi CompetiTestWrong   ctermfg=red    guifg=#ff0000
```

## Future plans
- [ ] Write Vim docs
- [ ] Integration with [competitive-companion](https://github.com/jmerle/competitive-companion) to download testcases and submit solutions
- [ ] Add an option to use split window instead of popup
- [ ] Handle interactive tasks

## Contributing
If you have any suggestion to give or if you encounter any trouble don't hesitate to open a new issue.\
Pull Requests are welcome! 🎉

## License
GNU Lesser General Public License version 3 (LGPL v3) or, at your option, any later version

Copyright © 2021, 2022 [xeluxee](https://github.com/xeluxee)

CompetiTest.nvim is free software: you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

CompetiTest.nvim is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License
along with CompetiTest.nvim. If not, see <https://www.gnu.org/licenses/>.

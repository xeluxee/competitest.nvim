# CompetiTest.nvim

<div align="center">

![Neovim](https://img.shields.io/badge/NeoVim-0.5+-%2357A143.svg?&style=for-the-badge&logo=neovim)
![Lua](https://img.shields.io/badge/Lua-%232C2D72.svg?style=for-the-badge&logo=lua)
![License](https://img.shields.io/github/license/xeluxee/competitest.nvim?style=for-the-badge&logo=gnu)

## Competitive Programming with Neovim made Easy

<!-- ![competitest_old](https://user-images.githubusercontent.com/88047141/147982101-2576e960-372c-4dec-b65e-97191c23a57d.png) -->
![competitest_popup_ui](https://user-images.githubusercontent.com/88047141/149839002-280069e5-0c71-4aec-8e39-4443a1c44f5c.png)
*CompetiTest's popup UI*

![competitest_split_ui](https://user-images.githubusercontent.com/88047141/183751179-e07e2a4d-e2eb-468b-ba34-bb737cba4557.png)
*CompetiTest's split UI*
</div>

`competitest.nvim` is a testcase manager and checker. It saves you time in competitive programming contests by automating common tasks related to testcase management. It can compile, run and test your solutions across all the available testcases, displaying results in a nice interactive user interface.

## Features
- Multiple languages supported: it works out of the box with C, C++, Rust, Java and Python, but other languages can be [configured](#customize-compile-and-run-commands)
- Flexible. No strict file-naming rules, optional fixed folder structure. You can choose where to put the source code file, the testcases, the received problems and contests, where to execute your programs and much more
- Configurable (see [Configuration](#configuration)). You can even configure [every folder individually](#local-configuration)
- Testcases can be stored in a single file or in multiple text files, see [usage notes](#usage-notes)
- Easily [add](#add-or-edit-a-testcase), [edit](#add-or-edit-a-testcase) and [delete](#remove-a-testcase) testcases
- [Run](#run-testcases) your program across all the testcases, showing results and execution data in a nice interactive UI
- [Stress test](#stress-testing) your program with random test cases, comparing outputs with a correct solution
- [Download](#receive-testcases-problems-and-contests) testcases, problems and contests automatically from competitive programming platforms
- [Templates](#templates-for-received-problems-and-contests) for received problems and contests
- View diff between actual and expected output
- [Customizable interface](#customize-ui-layout) that resizes automatically when Neovim window is resized
- Integration with [statusline and winbar](#statusline-and-winbar-integration)
- Customizable [highlight groups](#highlights)

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
	config = function() require('competitest').setup() end
}
```

Install with `lazy.nvim`:
``` lua
{
	'xeluxee/competitest.nvim',
	dependencies = 'MunifTanjim/nui.nvim',
	config = function() require('competitest').setup() end,
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
- A testcase is made by an input and an output (containing the correct answer)
- Input is necessary for a testcase to be considered, while an output hasn't to be provided necessarily
- Testcases can be stored in multiple text files or in a single [msgpack](https://msgpack.org/) encoded file
	- You can choose how to store them with `testcases_use_single_file` boolean option in in [configuration](#configuration). By default it's false, so multiple files are used
	- Storage method can be automatically detected when option `testcases_auto_detect_storage` is true
	- If you want to change the way already existing testcases are stored see [conversion](#convert-testcases)

#### Storing testcases in multiple text files
- To store testcases in multiple text files set `testcases_use_single_file` to false
- Files naming shall follow a rule to be recognized. Let's say your file is called `task-A.cpp`. If using the default configuration testcases associated with that file will be named `task-A_input0.txt`, `task-A_output0.txt`, `task-A_input1.txt`, `task-A_output1.txt` and so on. The counting starts from 0
- Of course files naming can be configured: see `testcases_input_file_format` and `testcases_output_file_format` in [configuration](#configuration)
- Testcases files can be put in the same folder of the source code file, but you can customize their path (see `testcases_directory` in [configuration](#configuration))

#### Storing testcases in a single file
- To store testcases in a single file set `testcases_use_single_file` to true
- Testcases file naming shall follow a rule to be recognized. Let's say your file is called `task-A.cpp`. If using the default configuration testcases file will be named `task-A.testcases`
- Of course single file naming can be configured: see `testcases_single_file_format` in [configuration](#configuration)
- Testcases file can be put in the same folder of the source code file, but you can customize its path (see `testcases_directory` in [configuration](#configuration))

Anyway you can forget about these rules if you use `:CompetiTest add_testcase` and `:CompetiTest edit_testcase`, that handle these things for you.

When launching the following commands make sure the focused buffer is the one containing the source code file.

### Add or Edit a testcase
Launch `:CompetiTest add_testcase` to add a new testcase.\
Launch `:CompetiTest edit_testcase` to edit an existing testcase. If you want to specify testcase number directly in the command line you can use `:CompetiTest edit_testcase x`, where `x` is a number representing the testcase you want to edit.

To jump between input and output windows press either `<C-h>`, `<C-l>`, or `<C-i>`. To save and close testcase editor press `<C-s>` or `:wq`.

Of course these keybindings can be customized: see `editor_ui` ➤ `normal_mode_mappings` and `editor_ui` ➤ `insert_mode_mappings` in [configuration](#configuration)

### Remove a testcase
Launch `:CompetiTest delete_testcase`. If you want to specify testcase number directly in the command line you can use `:CompetiTest delete_testcase x`, where `x` is a number representing the testcase you want to remove.

### Convert testcases
Testcases can be stored in multiple text files or in a single [msgpack](https://msgpack.org/) encoded file.\
Launch `:CompetiTest convert` to change testcases storage method: you can convert a single file into multiple files or vice versa.
One of the following arguments is needed:
- `singlefile_to_files`: convert a single file into multiple text files
- `files_to_singlefile`: convert multiple text files into a single file
- `auto`: if there's a single file convert it into multiple files, otherwise convert multiple files into a single file

**NOTE:** this command only converts already existing testcases files without changing CompetiTest configuration. To choose the storage method to use you have to [configure](#configuration) `testcases_use_single_file` option, that is false by default. Anyway storage method can be automatically detected when option `testcases_auto_detect_storage` is true.

### Run testcases
Launch `:CompetiTest run`. CompetiTest's interface will appear and you'll be able to view details about a testcase by moving the cursor over its entry. You can close the UI by pressing `q`, `Q` or `:q`.\
If you're using a compiled language and you don't want to recompile your program launch `:CompetiTest run_no_compile`.\
If you have previously closed the UI and you want to re-open it without re-executing testcases or recompiling launch `:CompetiTest show_ui`.

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
- Toggle diff view between actual and expected output by pressing `d` or `D`

Of course all these keybindings can be customized: see `runner_ui` ➤ `mappings` in [configuration](#configuration)

### Receive testcases, problems and contests
**NOTE:** to get this feature working you need to install [competitive-companion](https://github.com/jmerle/competitive-companion) extension in your browser.

Thanks to its integration with [competitive-companion](https://github.com/jmerle/competitive-companion), CompetiTest can download contents from competitive programming platforms:
- Download only testcases with `:CompetiTest receive testcases`
- Download a problem with `:CompetiTest receive problem` (source file is automatically created along with testcases)
- Download an entire contest with `:CompetiTest receive contest` (make sure to be on the homepage of the contest, not of a single problem)

After launching one of these commands click on the green plus button in your browser to start downloading.\
For further customization see receive options in [configuration](#configuration).

#### Customize folder structure
By default CompetiTest stores received problems and contests in current working directory. You can change this behavior through the options `received_problems_path`, `received_contests_directory` and `received_contests_problems_path`. See [receive modifiers](#receive-modifiers) for further details.\
Here are some tips:
- Fixed directory for received problems (not contests):
	``` lua
	received_problems_path = "$(HOME)/Competitive Programming/$(JUDGE)/$(CONTEST)/$(PROBLEM).$(FEXT)"
	```
- Fixed directory for received contests:
	``` lua
	received_contests_directory = "$(HOME)/Competitive Programming/$(JUDGE)/$(CONTEST)"
	```
- Put every problem of a contest in a different directory:
	``` lua
	received_contests_problems_path = "$(PROBLEM)/main.$(FEXT)"
	```
- Example of file naming for Java contests:
	``` lua
	received_contests_problems_path = "$(PROBLEM)/$(JAVA_MAIN_CLASS).$(FEXT)"
	```
- Simplified file names, it works with Java and any other language because the modifier `$(JAVA_TASK_CLASS)` is generated from problem name removing all non-alphabetic and non-numeric characters, including spaces and punctuation:
	``` lua
	received_contests_problems_path = "$(JAVA_TASK_CLASS).$(FEXT)"
	```

#### Templates for received problems and contests
When downloading a problem or a contest, source code templates can be configured for different file types. See `template_file` option in [configuration](#configuration).\
[Receive modifiers](#receive-modifiers) can be used inside template files to insert details about received problems. To enable this feature set `evaluate_template_modifiers` to `true`. Template example for C++:
``` cpp
// Problem: $(PROBLEM)
// Contest: $(CONTEST)
// Judge: $(JUDGE)
// URL: $(URL)
// Memory Limit: $(MEMLIM)
// Time Limit: $(TIMELIM)
// Start: $(DATE)

#include <iostream>
using namespace std;
int main() {
	cout << "This is a template file" << endl;
	cerr << "Problem name is $(PROBLEM)" << endl;
	return 0;
}
```

## Stress Testing
Launch `:CompetiTest stress` to start stress testing your program. The stress test window will appear showing:
- Current status (Running/Stopped)
- Runtime and number of tests passed
- Current test seed and failed seeds
- Generator, correct program and solution outputs when a test fails

You can control the stress test with:
- `K` to pause/continue testing
- `q` to stop and exit


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
		interface = "popup",
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
			toggle_diff = { "d", "D" },
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
	stress_ui = {
		width = 0.5,
		height = 0.6,
		mappings = {
			pause = "K",
			close = "q",
		},
	},
	popup_ui = {
		total_width = 0.8,
		total_height = 0.8,
		layout = {
			{ 3, "tc" },
			{ 4, {
				{ 1, "so" },
				{ 1, "si" },
			} },
			{ 4, {
				{ 1, "eo" },
				{ 1, "se" },
			} },
		},
	},
	split_ui = {
		position = "right",
		relative_to_editor = true,
		total_width = 0.3,
		vertical_layout = {
			{ 1, "tc" },
			{ 1, { { 1, "so" }, { 1, "eo" } } },
			{ 1, { { 1, "si" }, { 1, "se" } } },
		},
		total_height = 0.4,
		horizontal_layout = {
			{ 2, "tc" },
			{ 3, { { 1, "so" }, { 1, "si" } } },
			{ 3, { { 1, "eo" }, { 1, "se" } } },
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
	stress = {
		generator = {
			exec = "./$(FNOEXT)_gen",
			args = { "$(SEED)" },
		},
		correct = {
			exec = "./$(FNOEXT)_correct",
		},
		solution = {
			exec = "./$(FNOEXT)",
		},
		time_limit = 5000,
		seed_range = { 1, 1000000000 },
		auto_continue = true,
	},
	multiple_testing = -1,
	maximum_time = 5000,
	output_compare_method = "squish",
	view_output_diff = false,

	testcases_directory = ".",
	testcases_use_single_file = false,
	testcases_auto_detect_storage = true,
	testcases_single_file_format = "$(FNOEXT).testcases",
	testcases_input_file_format = "$(FNOEXT)_input$(TCNUM).txt",
	testcases_output_file_format = "$(FNOEXT)_output$(TCNUM).txt",

	companion_port = 27121,
	receive_print_message = true,
	template_file = false,
	evaluate_template_modifiers = false,
	date_format = "%c",
	received_files_extension = "cpp",
	received_problems_path = "$(CWD)/$(PROBLEM).$(FEXT)",
	received_problems_prompt_path = true,
	received_contests_directory = "$(CWD)",
	received_contests_problems_path = "$(PROBLEM).$(FEXT)",
	received_contests_prompt_directory = true,
	received_contests_prompt_extension = true,
	open_received_problems = true,
	open_received_contests = true,
	replace_received_testcases = false,
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
	- `interface`: interface used to display testcases data. Can be `popup` (floating windows) or `split` (normal windows). Associated settings can be found in `popup_ui` and `split_ui`
	- `selector_show_nu`: whether to show line numbers or not in testcase selector
	- `selector_show_rnu`: whether to show relative line numbers or not in testcase selector
	- `show_nu`: whether to show line numbers or not in details windows
	- `show_rnu`: whether to show relative line numbers or not in details windows
	- `mappings`: keyboard mappings used in testcase selector window
		- `run_again`: keymaps to run again a testcase
		- `run_all_again`: keymaps to run again all testcases
		- `kill`: keymaps to kill a testcase
		- `kill_all`: keymaps to kill all testcases
		- `view_input`: keymaps to view input (stdin) in a bigger window
		- `view_output`: keymaps to view expected output in a bigger window
		- `view_stdout`: keymaps to view programs's output (stdout) in a bigger window
		- `view_stderr`: keymaps to view programs's errors (stderr) in a bigger window
		- `toggle_diff`: keymaps to toggle diff view between actual and expected output
		- `close`: keymaps to close runner user interface
	- `viewer`: keyboard mappings used in [viewer window](#view-details)
		- `width`: a value from 0 to 1, representing the ratio between viewer window width and Neovim width
		- `height`: a value from 0 to 1, representing the ratio between viewer window height and Neovim height
		- `show_nu`: whether to show line numbers or not in viewer window
		- `show_rnu`: whether to show relative line numbers or not in viewer window
		- `close_mappings`: keymaps to close viewer window
- `popup_ui`: settings related to testcase runner popup interface
	- `total_width`: a value from 0 to 1, representing the ratio between total interface width and Neovim width
	- `total_height`: a value from 0 to 1, representing the ratio between total interface height and Neovim height
	- `layout`: a table describing popup UI layout. For further details see [here](#customize-ui-layout)
- `split_ui`: settings related to testcase runner split interface
	- `position`: can be `top`, `bottom`, `left` or `right`
	- `relative_to_editor`: whether to open split UI relatively to entire editor or to local window
	- `total_width`: a value from 0 to 1, representing the ratio between total **vertical** split width and relative window width
	- `vertical_layout`: a table describing vertical split UI layout. For further details see [here](#customize-ui-layout)
	- `total_height`: a value from 0 to 1, representing the ratio between total **horizontal** split height and relative window height
	- `horizontal_layout`: a table describing horizontal split UI layout. For further details see [here](#customize-ui-layout)
- `stress`: settings related to stress testing
	- `generator`: settings related to stress test generator
		- `exec`: command used to generate testcases
		- `args`: arguments passed to the generator command
	- `correct`: settings related to stress test correct program
		- `exec`: command used to run correct program
	- `solution`: settings related to stress test solution program
		- `exec`: command used to run solution program
	- `time_limit`: time limit for each test case, in milliseconds
	- `seed_range`: range of random seeds
	- `auto_continue`: whether to continue testing automatically
- `save_current_file`: if true save current file before running testcases
- `save_all_files`: if true save all the opened files before running testcases
- `compile_directory`: execution directory of compiler, relatively to current file's path
- `compile_command`: configure the command used to compile code for every different language, see [here](#customize-compile-and-run-commands)
- `running_directory`: execution directory of your solutions, relatively to current file's path
- `run_command`: configure the command used to run your solutions for every different language, see [here](#customize-compile-and-run-commands)
- `multiple_testing`: how many testcases to run at the same time
	- set it to `-1` to make the most of the amount of available parallelism. Often the number of testcases run at the same time coincides with the number of CPUs
	- set it to `0` if you want to run all the testcases together
	- set it to any positive integer to run that number of testcases contemporarily
- `maximum_time`: maximum time, in milliseconds, given to processes. If it's exceeded process will be killed
- `output_compare_method`: how given output (stdout) and expected output should be compared. It can be a string, representing the method to use, or a custom function. Available options follows:
	- `"exact"`: character by character comparison
	- `"squish"`: compare stripping extra white spaces and newlines
	- custom function: you can use a function accepting two arguments, two strings representing output and expected output. It should return true if the given output is acceptable, false otherwise. Example:
		``` lua
		require('competitest').setup {
			output_compare_method = function(output, expected_output)
				if output == expected_output then
					return true
				else
					return false
				end
			end
		}
		```
- `view_output_diff`: view diff between actual output and expected output in their respective windows
- `testcases_directory`: where testcases files are located, relatively to current file's path
- `testcases_use_single_file`: if true testcases will be stored in a single file instead of using multiple text files. If you want to change the way already existing testcases are stored see [conversion](#convert-testcases)
- `testcases_auto_detect_storage`: if true testcases storage method will be detected automatically. When both text files and single file are available, testcases will be loaded according to the preference specified in `testcases_use_single_file`
- `testcases_single_file_format`: string representing how single testcases files should be named (see [file-format modifiers](#file-format-modifiers))
- `testcases_input_file_format`: string representing how testcases input files should be named (see [file-format modifiers](#file-format-modifiers))
- `testcases_output_file_format`: string representing how testcases output files should be named (see [file-format modifiers](#file-format-modifiers))
- `companion_port`: competitive companion port number
- `receive_print_message`: if true notify user that plugin is ready to receive testcases, problems and contests or that they have just been received
- `template_file`: templates to use when creating source files for received problems or contests. Can be one of the following:
	- `false`: do not use templates
	- string with [file-format modifiers](#file-format-modifiers): useful when templates for different file types have a regular file naming
		``` lua
		template_file = "~/path/to/template.$(FEXT)"
		```
	- table with paths: table associating file extension to template file
		``` lua
		template_file = {
			c = "~/path/to/file.c",
			cpp = "~/path/to/file.cpp",
			py = "~/path/to/file.py",
		}
		```
- `evaluate_template_modifiers`: whether to evaluate [receive modifiers](#receive-modifiers) inside a template file or not
- `date_format`: string used to format `$(DATE)` modifier (see [receive modifiers](#receive-modifiers)). The string should follow the formatting rules as per Lua's [`os.date`](https://www.lua.org/pil/22.1.html) function. For example, to get `06-07-2023 15:24:32` set it to `%d-%m-%Y %H:%M:%S`
- `received_files_extension`: default file extension for received problems
- `received_problems_path`: path where received problems (not contests) are stored. Can be one of the following:
	- string with [receive modifiers](#receive-modifiers)
	- function: function accepting two arguments, a table with [task details](https://github.com/jmerle/competitive-companion/#the-format) and a string with preferred file extension. It should return the absolute path to store received problem. Example:
		``` lua
		received_problems_path = function(task, file_extension)
			local hyphen = string.find(task.group, " - ")
			local judge, contest
			if not hyphen then
				judge = task.group
				contest = "unknown_contest"
			else
				judge = string.sub(task.group, 1, hyphen - 1)
				contest = string.sub(task.group, hyphen + 3)
			end
			return string.format("%s/Competitive Programming/%s/%s/%s.%s", vim.loop.os_homedir(), judge, contest, task.name, file_extension)
		end
		```
- `received_problems_prompt_path`: whether to ask user confirmation about path where the received problem is stored or not
- `received_contests_directory`: directory where received contests are stored. It can be string or function, exactly as `received_problems_path`
- `received_contests_problems_path`: relative path from contest root directory, each problem of a received contest is stored following this option. It can be string or function, exactly as `received_problems_path`
- `received_contests_prompt_directory`: whether to ask user confirmation about the directory where received contests are stored or not
- `received_contests_prompt_extension`: whether to ask user confirmation about what file extension to use when receiving a contest or not
- `open_received_problems`: automatically open source files when receiving a single problem
- `open_received_contests`: automatically open source files when receiving a contest
- `replace_received_testcases`: this option applies when receiving only testcases. If true replace existing testcases with received ones, otherwise ask user what to do

### Local configuration
You can use a different configuration for every different folder by creating a file called `.competitest.lua` (this name can be changed configuring the option `local_config_file_name`). It will affect every file contained in that folder and in subfolders. A table containing valid options must be returned, see the following example.
``` lua
-- .competitest.lua content
return {
	multiple_testing = 3,
	maximum_time = 2500,
	testcases_input_file_format = "in_$(TCNUM).txt",
	testcases_output_file_format = "ans_$(TCNUM).txt",
	testcases_single_file_format = "$(FNOEXT).tc",
}
```

### Available modifiers
Modifiers are substrings that will be replaced by another string, depending on the modifier and the context. They're used to tweak some options.

#### File-format modifiers
You can use them to [define commands](#customize-compile-and-run-commands) or to customize testcases files naming through options `testcases_single_file_format`, `testcases_input_file_format` and `testcases_output_file_format`.

| Modifier      | Meaning                                    |
| --------      | -------                                    |
| `$()`         | insert a dollar                            |
| `$(HOME)`     | user home directory                        |
| `$(FNAME)`    | file name                                  |
| `$(FNOEXT)`   | file name without extension                |
| `$(FEXT)`     | file extension                             |
| `$(FABSPATH)` | absolute path of current file              |
| `$(ABSDIR)`   | absolute path of folder that contains file |
| `$(TCNUM)`    | testcase number                            |

#### Receive modifiers
You can use them to customize the options `received_problems_path`, `received_contests_directory`, `received_contests_problems_path` and to [insert problem details inside template files](#templates-for-received-problems-and-contests). See also [tips for customizing folder structure for received problems and contests](#customize-folder-structure).

| Modifier             | Meaning                                                       |
| --------             | -------                                                       |
| `$()`                | insert a dollar                                               |
| `$(HOME)`            | user home directory                                           |
| `$(CWD)`             | current working directory                                     |
| `$(FEXT)`            | preferred file extension                                      |
| `$(PROBLEM)`         | problem name, `name` field                                    |
| `$(GROUP)`           | judge and contest name, `group` field                         |
| `$(JUDGE)`           | judge name (first part of `group`, before hyphen)             |
| `$(CONTEST)`         | contest name (second part of `group`, after hyphen)           |
| `$(URL)`             | problem url, `url` field                                      |
| `$(MEMLIM)`          | available memory, `memoryLimit` field                         |
| `$(TIMELIM)`         | time limit, `timeLimit` field                                 |
| `$(JAVA_MAIN_CLASS)` | almost always "Main", `mainClass` field                       |
| `$(JAVA_TASK_CLASS)` | classname-friendly version of problem name, `taskClass` field |
| `$(DATE)`            | current date and time (based on [`date_format`](#explanation)), it can be used only inside [template files](#templates-for-received-problems-and-contests) |

Fields are referred to [received tasks](https://github.com/jmerle/competitive-companion/#the-format).

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
See [file-format modifiers](#file-format-modifiers) to better understand how dollar notation works.

**NOTE:** if your language isn't compiled you can ignore `compile_command` section.

Feel free to open a PR or an issue if you think it's worth adding a new language among default ones.

### Customize UI layout
You can customize testcase runner user interface by defining windows positions and sizes trough a table describing a layout. This is possible both for popup and split UI.

Every window is identified by a string representing its name and a number representing the proportion between its size and the sizes of other windows. To define a window use a lua table made by a number and a string. An example is `{ 1.5, "tc" }`.\
Windows can be named as follows:
- `tc` for testcases selector
- `si` for standard input
- `so` for standard output
- `se` for standard error
- `eo` for expected output

A layout is a list made by windows or layouts (recursively defined). To define a layout use a lua table containing a list of windows or layouts.

<table>
<tr> <th>Sample code</th> <th>Result</th> </tr>
<tr> <td>

``` lua
layout = {
  { 2, "tc" },
  { 3, {
       { 1, "so" },
       { 1, "si" },
     } },
  { 3, {
       { 1, "eo" },
       { 1, "se" },
     } },
}
```
</td> <td>

![layout1](https://user-images.githubusercontent.com/88047141/183749940-b720e9b2-557d-460c-99d0-99a2a03a81bd.png)
</td> </tr>
<tr> <td>

``` lua
layout = {
  { 1, {
       { 1, "so" },
       { 1, {
            { 1, "tc" },
            { 1, "se" },
          } },
     } },
  { 1, {
       { 1, "eo" },
       { 1, "si" },
     } },
}
```
</td> <td>

![layout2](https://user-images.githubusercontent.com/88047141/183750135-6dbd39ac-2fd4-4c10-be5f-034c1966929f.png)
</td> </tr>
</table>

## Statusline and winbar integration
When using split UI windows name can be displayed in statusline or in winbar. In each CompetiTest buffer there's a local variable called `competitest_title`, that is a string representing window name. You can get its value using `nvim_buf_get_var(buffer_number, 'competitest_title')`.\
See the [second screenshot](#competitive-programming-with-neovim-made-easy) for an example statusline used with split UI.

## Highlights
You can customize CompetiTest highlight groups. Their default values are:
``` vim
hi CompetiTestRunning cterm=bold     gui=bold
hi CompetiTestDone    cterm=none     gui=none
hi CompetiTestCorrect ctermfg=green  guifg=#00ff00
hi CompetiTestWarning ctermfg=yellow guifg=orange
hi CompetiTestWrong   ctermfg=red    guifg=#ff0000
```

## Roadmap
- [x] Manage testcases
	- [x] Add testcases
	- [x] Edit testcases
	- [x] Delete testcases
	- [x] Store testcases in a single file
	- [x] Store testcases in multiple text files
	- [x] Convert single file into multiple text files and vice versa
- [x] Run testcases
	- [x] Support many programming languages
	- [x] Handle compilation if needed
	- [x] Run multiple testcases at the same time
		- [x] Run again processes
		- [x] Kill processes
	- [x] Display results and execution data in a popup UI
	- [x] Display results and execution data in a split window UI
- [ ] Handle interactive tasks
- [x] Configure every folder individually
- [x] Integration with [competitive-companion](https://github.com/jmerle/competitive-companion)
	- [x] Download testcases
	- [x] Download problems
	- [x] Download contests
	- [x] Customizable folder structure for downloaded problems and contests
- [x] Templates for files created when receiving problems or contests
- [ ] Integration with tools to submit solutions ([api-client](https://github.com/online-judge-tools/api-client) or [cpbooster](https://github.com/searleser97/cpbooster))
- [ ] Write Vim docs
- [x] Customizable highlights
- [x] Resizable UI

## Contributing
If you have any suggestion to give or if you encounter any trouble don't hesitate to open a new issue.\
Pull Requests are welcome! 🎉

## License
GNU Lesser General Public License version 3 (LGPL v3) or, at your option, any later version

Copyright © 2021-2023 [xeluxee](https://github.com/xeluxee)

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

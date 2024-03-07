# EasyParallel

## Overview

`EasyParallel` is designed to simplify the process of performing **embarrassingly parallel** computations, a common scenario in physical research using Monte Carlo simulations. This project aims to make it easier for researchers and developers to implement and execute parallel tasks easily and efficiently.

## Features

- **Simplified Parallel Computing**: `EasyParallel` abstracts away the complexities of parallel computation, allowing users to focus on their research without worrying about the underlying parallelization logic.
- **Designed for Monte Carlo Simulations**: Tailored to meet the needs of physical researchers, facilitating the acceleration of Monte Carlo simulation tasks.
- **Easy Integration**: By adopting a predefined file structure and specifying parallel parameters, users can easily integrate `EasyParallel` into their projects.

## Getting Started

Ensure Julia is installed on your system. `Pkg.add` all required packages

Clone the repository to your local machine

## Usage

To use `EasyParallel`, follow these steps:

1. **Adopt the File Structure**: Organize your project files according to the `EasyParallel` file structure.
2. **Define Parallel Parameters**: Specify `ParallelParam` that includes all parallel configurations needed.
3. **Run Parallel Function**: Simply execute the `parallel` function! It will automatically manage and distribute tasks across multiple processes.
4. **Restore all your results**: Even during execution, you can see a summary of current progress by one command `data_readout(timename)`

For detailed usage and examples, please refer to the `experiments/example_0101`

## Contributing

We wellcome contributions to `EasyParallel` in all forms! Whether it's reporting a bug, discussing improvements, or contributing code, we value your input and contributions to make `EasyParallel` better for everyone.

## License

The EasyParallel project is licensed under the Apache License, Version 2.0 - see the LICENSE file for details.

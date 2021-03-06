# `quarto-render` Github action demonstration: a non-frozen project.

Demonstration of the `quarto-render` ([link](https://github.com/pommevilla/quarto-render)) Github action on a Quarto project [without freeze](https://quarto.org/docs/books/book-authoring.html?q=freeze#freezing). 

`sample_analysis.Rmd` and `rosalind_problems.ipynb` both contain code written in R or Python that require external libraries to perform their computations; in the case of `sample_analysis.Rmd`, this is a considerable amount of external libraries and some non-trivial computations. It is possible to use the `quarto-render` Github action in this case if you reinstall the package dependencies before using `quarto-render`. 

* For R libraries, use `renv` to capture dependencies for your RMarkdown code and use it to restore your environment in your workflow. 
  * Example job steps are [here](https://rstudio.github.io/renv/articles/ci.html#github-actions-1). 
  * Read more about `renv` at the [package site](https://rstudio.github.io/renv/articles/renv.html).
* Use `pip freeze > requirements.txt` to capture Python package requirements. You can then restore your environment via `pip install -r requirements.txt`
  * Note that if you are on a Windows machine and running a Github workflow on a non-Windows image, then the above command should be modified to `pip freeze | grep -iv "win" > requirements.txt` to avoid capturing Windows-specific pacakges in your `requirements.txt`. These packages will cause errors when attempting installation on non-Windows machine.

Below is the workflow used in this directory to restore the Python and R dependencies required for these documents, render them with the `quarto-render` Github action, and push them to the `gh-pages` branch with `action-gh-pages` ([link](https://github.com/peaceiris/actions-gh-pages)). 

## Github Workflow

```yaml
# .github/workflows/render-and-deploy.yml
name: Render and deploy Quarto files
on: 
  push:
  pull_request:

jobs:
  quarto-render-and-deploy:
    runs-on: ubuntu-latest
    env:
      RENV_PATHS_ROOT: ~/.local/share/renv
    steps:
    - uses: actions/checkout@v2

    - uses: actions/setup-python@v2

    - name: "Install Python deps"
      run: |
        pip install -r requirements.txt

    - uses: r-lib/actions/setup-r@v1

    - name: "Install curl for Bioconductor"
      run: |
        sudo apt -y install libcurl4-openssl-dev

    - name: "Install R Packages: Cache packages"
      uses: actions/cache@v1
      with:
        path: ${{ env.RENV_PATHS_ROOT }}
        key: ${{ runner.os }}-renv-${{ hashFiles('**/renv.lock') }}
        restore-keys: |
          ${{ runner.os }}-renv-

    - name: "Install R Packages: Restore packages"
      shell: Rscript {0}
      run: |
        if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv")
        renv::restore()

    - name: "Install Quarto and render"
      uses: pommevilla/quarto-render@main

    - name: "Deploy to gh-pages"
      uses: peaceiris/actions-gh-pages@v3
      if: github.ref == 'refs/heads/main'
      with:
        github_token: ${{ secrets.GITHUB_TOKEN }}
        publish_dir: ./_site
```

The final results can be viewed [https://pommevilla.github.io/hinterland-harbor/](here).

## You should probably use `freeze`

While it is an option to use `quarto-render` without freeze in this way, it is generally not recommended for a few reasons:

* You have to version control any data sets that are used in the computation of your documents, which can be quite large.
* While it is good practice to version control your package dependencies, restoring them during the Github workflow creates additional opportunities for failure, especially if you are using non-CRAN libraries such as those from [Bioconductor](https://www.bioconductor.org/). 
* Restoring packages in a workflow from `renv` can take a significant amount of time on the initial run. While future workflows will finish more quickly by taking advantage of the package cache, the initial run can take quite a bit of time to complete, making it difficult to troubleshoot. For example, the initial render of this repository took [over 45 minutes](https://github.com/pommevilla/hinterland-harbor/runs/2919380857?check_suite_focus=true).
* The documents are recomputed at render time. This means that if you have a document with a lot of expensive computations, it will take longer to complete a workflow and see your results. As a comparison, after the initial cache is created by `renv`, running a `quarto-render` workflow [takes about 2 minutes](https://github.com/pommevilla/hinterland-harbor/runs/2921322559?check_suite_focus=true), while a [similar workflow](https://github.com/pommevilla/friendly-dollop/blob/master/.github/workflows/quarto-render.yml) that takes advantage of `freeze` finishes rendering its documents in [under 30 seconds](https://github.com/pommevilla/friendly-dollop/runs/2917945915?check_suite_focus=true), even though it contains more documents with more computations.

For these reasons, it is suggested that you take advantage of the `freeze` execution mode for your Quarto projects. See [this repo](https://github.com/pommevilla/friendly-dollop) for an example Quarto project that used `freeze` and `quarto-render` to simplify the Github page publishing process.

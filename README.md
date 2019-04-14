# Save the change

Similar to a certain US banking institution, read a `csv` file containing dates and charges. Based on the grouping type, round up the transactions to the nearest dollar and return a summary of how much was rounded up (this amount is also rounded up).

## save_the_change.py

### Usage

`python3 save_the_change.py <input.csv>`

### Input format

`save_the_change.py` excepts `<input.csv>` to contain two columns, separated by a `,`. The first column is the date the charge was made in _mm/dd/yyyy_ format. The second column is the amount the charge was for. The charges can either be all negative or all positive.

### Output

`save_the_change.py` will provide three lines of output
    
    1. The rounded up amount based on individual transactions.
    2. The rounded up amount of all transaction per day.
    3. The rounded up amount of all transaction per calendar week.

## prep-statement.sh

In an effort to help stream line the process, `prep-statement.sh` will read in a more raw `csv` file and create a temporary file, the contents of which is suitable for input to `save_the_change.py`

### Usage

`prep-statement.sh <raw_input.csv>`

### Input format

`<raw_input.csv>` is expected to contain many columns, separated by `,` with the first column being the date the charge was made in _mm/dd/yyyy_ format and the last column to be the amount the charge was made for. In future it will be possible to change the expected arrangement of the columns.

### Output

Upon success, `prep-statement.sh` will print the absolute path to the temporary file that can be given to `save_the_change.py`.

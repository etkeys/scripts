# pylint: disable=missing-docstring

import csv
from datetime import datetime
import itertools
import math
import sys

def main():
    in_file = sys.argv[1]
    records = get_valid_records(in_file)
   
    print_amount("Transaction", records, calculate_by_transaction)
    print_amount("Day", records, calculate_by_day)
    print_amount("Week", records, calculate_by_week)


def get_valid_records(file_path):
    result = []

    with open(file_path, 'r') as f:
        reader = csv.reader(f, delimiter=',')

        for row in reader:
            record = (
                datetime.strptime(row[0], '%m/%d/%Y').date(),
                float(row[1]))

            if record[1] < 0:
                result.append(record)

    return result

def print_amount(amount_type, records, func):
    print(
        f"Amount by {amount_type}: $ {int(math.ceil(func(records)))}")

def calculate_by_transaction(records):
    result = 0.0

    for _, amount in records:
        fabs_amount = math.fabs(amount)
        result += math.ceil(fabs_amount) - fabs_amount

    return result

def calculate_by_day(records):
    groups = itertools.groupby(records, lambda r: r[0].toordinal())

    result = 0.0
    for _, group in groups:
        fabs_daily = math.fsum([math.fabs(amount) for _, amount in group])
        result += math.ceil(fabs_daily) - fabs_daily

    return result

def calculate_by_week(records):
    groups = itertools.groupby(records, lambda r: r[0].isocalendar()[1])

    result = 0.0
    for _, group in groups:
        fabs_weekly = math.fsum([math.fabs(amount) for _, amount in group])
        result += math.ceil(fabs_weekly) - fabs_weekly

    return result

if __name__ == '__main__':
    main()

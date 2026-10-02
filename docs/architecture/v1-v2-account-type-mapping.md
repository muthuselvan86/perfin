# V1 to V2 account-type mapping

Source: V1 `app/lib/placeholder-data.js`, category definitions only. This covers all 32 source subcategories. It is not a live database inventory or an executable data migration. V1 can contain categories added outside that file; inventory those before importing records.

V2 has 7 categories and 38 account types. The seed retains all original 18 V2 codes and adds 20 types. It inserts missing reference rows without altering existing accounts or reference IDs.

## Direct mappings

These map classification labels, not IDs, users, balances, or credentials. Country and native currency must be supplied from verified account information; V1's USD display does not prove an account's actual currency.

| V1 parent | V1 subcategory | V2 category | V2 account-type code |
|---|---|---|---|
| Cash Equivalents | Checking Accounts | CASH | CHECKING |
| Cash Equivalents | Saving Accounts | CASH | SAVINGS |
| Cash Equivalents | Money Market Accounts | CASH | MONEY_MARKET |
| Cash Equivalents | Certificates of Deposits | CASH | CERTIFICATE_OF_DEPOSIT |
| Cash Equivalents | Cash | CASH | CASH_ON_HAND |
| Cash Equivalents | High Yield Savings | CASH | HIGH_YIELD_SAVINGS |
| Cash Equivalents | Brokerage Savings | CASH | BROKERAGE_SAVINGS |
| Investments | Stocks | INVESTMENTS | STOCKS |
| Investments | Bonds | INVESTMENTS | BONDS |
| Investments | REITs | INVESTMENTS | REITS |
| Investments | Alternative Investments | INVESTMENTS | ALTERNATIVE_INVESTMENTS |
| Investments | Educational Savings Accounts(529 Plan) | INVESTMENTS | EDUCATION_529 |
| Retirement Accounts | Traditional IRAs | RETIREMENT | TRADITIONAL_IRA |
| Retirement Accounts | Roth IRAs | RETIREMENT | ROTH_IRA |
| Retirement Accounts | 401(k)s | RETIREMENT | RETIREMENT_401K |
| Retirement Accounts | Pensions | RETIREMENT | PENSION |
| Personal Property | Vehicles | PERSONAL_PROPERTY | VEHICLE |
| Personal Property | Jewelry | PERSONAL_PROPERTY | JEWELRY |
| Personal Property | Collectibles | PERSONAL_PROPERTY | COLLECTIBLES |
| Personal Property | Electronics | PERSONAL_PROPERTY | ELECTRONICS |
| Personal Property | Furniture | PERSONAL_PROPERTY | FURNITURE |
| Real Estate | Primary Residence | REAL_ESTATE | PRIMARY_RESIDENCE |
| Real Estate | Rental Property | REAL_ESTATE | RENTAL_PROPERTY |
| Liabilities | Mortgages | LOANS | MORTGAGE |
| Liabilities | Credit Card | CREDIT | CREDIT_CARD |
| Liabilities | Student Loans | LOANS | STUDENT_LOAN |
| Liabilities | Car Loan | LOANS | AUTO_LOAN |
| Liabilities | Personal Loan | LOANS | PERSONAL_LOAN |

Stocks, bonds, REITs, and mutual funds are retained as account-level classifications for parity. This does not introduce security holdings, quantities, or transactions. A mixed investment account can use BROKERAGE; do not split its balance into multiple accounts solely to satisfy the old category label.

## Foreign assets: review required

Foreign Assets is no longer a category. Use the actual financial classification, country, and native currency.

| V1 subcategory | V2 treatment |
|---|---|
| Ind Cash | CASH; choose SAVINGS, CHECKING, CASH_ON_HAND, FIXED_DEPOSIT, or another verified cash type |
| Ind Stock | INVESTMENTS; STOCKS for an equity-valued record or BROKERAGE for a mixed brokerage account after review |
| Ind Real Estate | REAL_ESTATE; choose PRIMARY_RESIDENCE, RENTAL_PROPERTY, LAND, or HOME after review |
| Other Ind Assets | Explicit manual classification; no automatic default |

These labels suggest country IN, but verify it during import. Do not assume INR solely from country; some India-based accounts hold other currencies. V1 balances may already be converted, so confirm the amount's denomination before storing it as a native balance. Unsupported currencies require a separate decision rather than relabeling them USD or INR.

## Initial V2 types retained

FIXED_DEPOSIT, BROKERAGE, MUTUAL_FUNDS, IRA, EPF, PPF, HOME, LAND, VALUABLES, and LINE_OF_CREDIT remain alongside V1-compatible types. Generic IRA does not imply Traditional IRA, and HOME does not imply primary residence. Existing records keep their original type unless explicitly reclassified later.

## Reseeding and validation

From the project root:

```bash
npm run db:seed
```

A fresh or unchanged earlier V2 catalog should contain 7 categories and 38 types afterward. Extra user-created reference rows are not deleted. Reruns should not increase these catalog counts or modify financial records. Seeding is separate from migrating V1 data, which requires explicit household/member assignment, ownership conversion, denomination verification, and reconciliation.

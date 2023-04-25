
public class AccountsSelector extends SObjectSelectorImpl {
    public override SObjectType getSObjectType() {
        return Account.getSObjectType();
    }
    public override List<SObjectField> getSObjectFieldList() {
        return new List<SObjectField>{
                Account.Name,
                Account.Description,
                Account.AnnualRevenue
        };
    }

    public List<Account> getAccountsByIds(List<Id> ids) {
        return (List<Account>) selectByIds(ids);
    }
}
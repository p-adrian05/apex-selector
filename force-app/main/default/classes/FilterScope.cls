
/**
    Enums using for USING SCOPE clause of an SOQL query returns records within a specified scope.
 */
public enum FilterScope {
    delegated,
    everything,
    mine,
    mine_and_my_groups,
    my_territory,
    my_team_territory,
    scopingRule,
    team
}
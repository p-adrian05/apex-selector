@IsTest
public with sharing class OptionalTest {

    @IsTest
    public static void testOptionalOfShouldReturnOptionalInstance(){
        String value = 'val';
        Optional optional = Optional.of(value);

        Assert.isFalse(optional.isEmpty());
        Assert.isTrue(optional.isPresent());
        Assert.areEqual(value,optional.get());
        Assert.isTrue(optional.toString().contains(value));
    }
    @IsTest
    public static void testOptionalOfNullableShouldReturnOptionalInstance(){
        String value = 'val';
        Optional optionalOfNullable = Optional.of(value);
        String nullValue;
        Optional optionalOfNull = Optional.ofNullable(nullValue);

        Assert.isTrue(optionalOfNullable.isPresent());
        Assert.isFalse(optionalOfNullable.isEmpty());
        Assert.areEqual(value,optionalOfNullable.get());

        Assert.isTrue(optionalOfNull.isEmpty());
        Assert.isFalse(optionalOfNull.isPresent());
        Assert.isTrue(optionalOfNull.toString().containsIgnoreCase('empty'));

        String exceptionMessage;
        try{
            optionalOfNull.get();
        }catch (Exception e){
            exceptionMessage = e.getMessage();
        }
        Assert.isNotNull(exceptionMessage);
    }
}
@IsTest
public with sharing class OptionalTest {

    @IsTest
    public static void testOptionalOfShouldReturnOptionalInstance(){
        String value = 'val';
        Optional optional = Optional.of(value);

        System.assert(!optional.isEmpty());
        System.assert(optional.isPresent());
        System.assert(optional.get()==value);
        System.assert(optional.toString().contains(value));
    }
    @IsTest
    public static void testOptionalOfNullableShouldReturnOptionalInstance(){
        String value = 'val';
        Optional optionalOfNullable = Optional.of(value);
        String nullValue;
        Optional optionalOfNull = Optional.ofNullable(nullValue);

        System.assert(optionalOfNullable.isPresent());
        System.assert(!optionalOfNullable.isEmpty());
        System.assert(optionalOfNullable.get()==value);

        System.assert(optionalOfNull.isEmpty());
        System.assert(!optionalOfNull.isPresent());
        System.assert(optionalOfNull.toString().containsIgnoreCase('empty'));

        String exceptionMessage;
        try{
            optionalOfNull.get();
        }catch (Exception e){
            exceptionMessage = e.getMessage();
        }
        System.assert(exceptionMessage!=null);
    }
}
public class Optional {

    private final Object value;

    private Optional(Object value) {
        this.value = value;
    }

    private static final Optional EMPTY = new Optional(null);

    public static Optional of(Object value){
        return new Optional(value);
    }
    public static Optional ofNullable(Object value) {
        return value == null ? EMPTY : new Optional(value);
    }

    /**
     * If a value is present, returns the value, otherwise throws
     * {@code NoSuchElementException}.
     *
     *
     * @return the non-{@code null} value described by this {@code Optional}
     * @throws NoSuchElementException if no value is present
     */
    public Object get() {
        if (value == null) {
            throw new NoSuchElementException('No value present');
        }
        return value;
    }

    /**
     * If a value is present, returns {@code true}, otherwise {@code false}.
     *
     * @return {@code true} if a value is present, otherwise {@code false}
     */
    public Boolean isPresent() {
        return value != null;
    }

    /**
     * If a value is  not present, returns {@code true}, otherwise
     * {@code false}.
     *
     * @return  {@code true} if a value is not present, otherwise {@code false}
     */
    public Boolean isEmpty() {
        return value == null;
    }

    public override String toString() {
        return value != null
        ? 'Optional['+value+']'
        : 'Optional.empty';
    }


}
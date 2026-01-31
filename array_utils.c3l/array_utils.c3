module array_utils::uts <Type>;

alias GrepFunction = fn bool(Type elt);
alias MapFunction = fn Type(Type elt);
alias ListType = List {Type};

<*
 Returns count of element in array

 @param [in] self
 @param [in] element
*>
fn usz Type[].count_contains(self, Type element)
{
    usz result = 0;
	foreach (&item : self)
	{
		if (*item == element) result++;
	}
	return result;
}

fn usz Type[].index_of(self, Type element){
	foreach (index, &item : self)
	{
		if (*item == element){
            return index;
        }
	}
	return -1;
}

<*
 @ensure -1 < return && return < self.len
*>
fn bool Type[].contains(self, Type element){
    return self.index_of(element) > -1;
}

fn Type[] Type[].grep(self, Allocator allocator, GrepFunction grep_function) {
    ListType result;
    result.init(allocator, self.len);
    foreach(elt : self){
        if(grep_function(elt)){
            result.push(elt);
        }
    }
    return result.array_view();
}

fn Type[] Type[].map(self, Allocator allocator, MapFunction map_function) {
    ListType result;
    result.init(allocator, self.len);
    foreach(elt : self){
        result.push(map_function(elt));
    }
    //result.print_diag("result");
    return result.array_view();
}

fn Type[] Type[].copy_array(self, Allocator allocator){
    usz capacity = self.len + 1;
	Type* holder = allocator::alloc_array(allocator, Type, capacity);
    usz index = 0;
    foreach(elt : self){
		holder[index++] = elt;
    }
	return holder[:index];
}

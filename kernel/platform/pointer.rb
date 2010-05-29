module FFI

  ##
  # Pointer is Rubinius's "fat" pointer class. It represents an actual
  # pointer, in C language terms, to an address in memory. They're called
  # fat pointers because the Pointer object is an wrapper around
  # the actual pointer, the Rubinius runtime doesn't have direct access
  # to the raw address.
  #
  # This class is used extensively in FFI usage to interface with various
  # parts of the underlying system. It provides a number of operations
  # for operating on the memory that is pointed to. These operations effectively
  # give Rubinius the cast/read capabilities available in C, but using
  # high level methods.
  #
  # MemoryPointer objects can be put in autorelease mode. In this mode,
  # when the GC cleans up a MemoryPointer object, the memory it points
  # to is passed to free(3), releasing the memory back to the OS.
  #
  # NOTE: MemoryPointer exposes direct, unmanaged operations on any
  # memory. It therefore MUST be used carefully. Reading or writing to
  # invalid address will cause bus errors and segmentation faults.
  #
  class Pointer
    def initialize(a1, a2=undefined)
      if a2.equal? undefined
        self.address = a1
      else
        @type = a1
        self.address = a2
      end
    end

    def inspect
      # Don't have this print the data at the location. It can crash everything.
      addr = address()

      if addr < 0
        sign = "-"
        addr = -addr
      else
        sign = ""
      end

      "#<#{self.class.name} address=#{sign}0x#{addr.to_s(16)}>"
    end

    def address
      Ruby.primitive :pointer_address
      raise PrimitiveFailure, "Unable to find address"
    end

    alias_method :to_i, :address

    def address=(address)
      Ruby.primitive :pointer_set_address
      raise PrimitiveFailure, "MemoryPointer#address= primitive failed"
    end

    def null?
      address == 0x0
    end

    def +(value)
      Ruby.primitive :pointer_add
      raise PrimitiveFailure, "Unable to add"
    end

    def ==(other)
      return false unless other.kind_of? Pointer
      return address == other.address
    end

    # Below here are methods for reading and writing memory pointed to
    #
    # Write +obj+ as a C short at the memory pointed to.
    def write_short(obj)
      Ruby.primitive :pointer_write_short
      raise PrimitiveFailure, "Unable to write short"
    end

    # Read a C short from the memory pointed to.
    def read_short
      Ruby.primitive :pointer_read_short
      raise PrimitiveFailure, "Unable to read short"
    end

    # Write +obj+ as a C int at the memory pointed to.
    def write_int(obj)
      Ruby.primitive :pointer_write_int
      raise PrimitiveFailure, "Unable to write integer"
    end

    def read_int(sign=true)
      read_int_signed(sign)
    end

    # Read a C int from the memory pointed to.
    def read_int_signed(sign)
      Ruby.primitive :pointer_read_int
      raise PrimitiveFailure, "Unable to read integer"
    end

    # Write +obj+ as a C long at the memory pointed to.
    def write_long(obj)
      Ruby.primitive :pointer_write_long
      raise PrimitiveFailure, "Unable to write long"
    end

    # Read a C long from the memory pointed to.
    def read_long
      Ruby.primitive :pointer_read_long
      raise PrimitiveFailure, "Unable to read long"
    end

    # Write +obj+ as a C long long at the memory pointed to.
    def write_long_long(obj)
      Ruby.primitive :pointer_write_long_long
      raise PrimitiveFailure, "Unable to write long long"
    end

    alias_method :write_int64, :write_long_long

    # Read a C long from the memory pointed to.
    def read_long_long
      Ruby.primitive :pointer_read_long_long
      raise PrimitiveFailure, "Unable to read long long"
    end

    alias_method :read_int64, :read_long_long

    def network_order(start, size)
      Ruby.primitive :pointer_network_order
      raise PrimitiveFailure, "Unable to convert to network order"
    end

    def read_string_length(len)
      Ruby.primitive :pointer_read_string
      raise PrimitiveFailure, "Unable to read string"
    end

    def read_string_to_null
      Ruby.primitive :pointer_read_string_to_null
      raise PrimitiveFailure, "Unable to read string to null"
    end

    def read_string(len=nil)
      if len
        read_string_length(len)
      else
        read_string_to_null
      end
    end

    def write_string_length(str, len)
      Ruby.primitive :pointer_write_string
      raise PrimitiveFailure, "Unable to write string"
    end

    def write_string(str, len=nil)
      len = str.size unless len

      write_string_length(str, len);
    end

    def read_pointer
      Ruby.primitive :pointer_read_pointer
      raise PrimitiveFailure, "Unable to read pointer"
    end

    def write_float(obj)
      Ruby.primitive :pointer_write_float
      raise PrimitiveFailure, "Unable to write float"
    end

    def read_float
      Ruby.primitive :pointer_read_float
      raise PrimitiveFailure, "Unable to read float"
    end
    
    def write_double(obj)
      Ruby.primitive :pointer_write_double
      raise PrimitiveFailure, "Unable to write double"
    end
    
    def read_double
      Ruby.primitive :pointer_read_double
      raise PrimitiveFailure, "Unable to read double"
    end

    def read_array_of_int(length)
      read_array_of_type(:int, :read_int, length)
    end

    def write_array_of_int(ary)
      write_array_of_type(:int, :write_int, ary)
    end

    def read_array_of_long(length)
      read_array_of_type(:long, :read_long, length)
    end

    def write_array_of_long(ary)
      write_array_of_type(:long, :write_long, ary)
    end

    def read_array_of_type(type, reader, length)
      ary = []
      size = FFI.type_size(FFI.find_type type)
      tmp = self
      length.times {
        ary << tmp.send(reader)
        tmp += size
      }
      ary
    end

    def write_array_of_type(type, writer, ary)
      size = FFI.type_size(FFI.find_type type)
      tmp = self
      ary.each do |i|
        tmp.send(writer, i)
        tmp += size
      end
      self
    end

    def get_at_offset(offset, type)
      Ruby.primitive :pointer_get_at_offset
      raise PrimitiveFailure, "get_field failed"
    end

    def set_at_offset(offset, type, val)
      Ruby.primitive :pointer_set_at_offset
      raise PrimitiveFailure, "set_field failed"
    end

  end

  class MemoryPointer < Pointer

    # call-seq:
    #   MemoryPointer.new(num) => MemoryPointer instance of <i>num</i> bytes
    #   MemoryPointer.new(sym) => MemoryPointer instance with number
    #                             of bytes need by FFI type <i>sym</i>
    #   MemoryPointer.new(obj) => MemoryPointer instance with number
    #                             of <i>obj.size</i> bytes
    #   MemoryPointer.new(sym, count) => MemoryPointer instance with number
    #                             of bytes need by length-<i>count</i> array
    #                             of FFI type <i>sym</i>
    #   MemoryPointer.new(obj, count) => MemoryPointer instance with number
    #                             of bytes need by length-<i>count</i> array
    #                             of <i>obj.size</i> bytes
    #   MemoryPointer.new(arg) { |p| ... }
    #
    # Both forms create a MemoryPointer instance. The number of bytes to
    # allocate is either specified directly or by passing an FFI type, which
    # specifies the number of bytes needed for that type.
    #
    # The form without a block returns the MemoryPointer instance. The form
    # with a block yields the MemoryPointer instance and frees the memory
    # when the block returns. The value returned is the value of the block.

    def self.new(type, count=nil, clear=true)
      if type.kind_of? Fixnum
        size = type
      elsif type.kind_of? Symbol
        type = FFI.find_type type
        size = FFI.type_size(type)
      else
        size = type.size
      end

      if count
        total = size * count
      else
        total = size
      end

      ptr = malloc total
      ptr.total = total
      ptr.type_size = size
      FFI::Platform::POSIX.memset ptr, 0, total if clear

      if block_given?
        begin
          value = yield ptr
        ensure
          ptr.free
        end

        return value
      else
        ptr.autorelease = true
        ptr
      end
    end

    def self.malloc(total)
      Ruby.primitive :pointer_malloc
      raise PrimitiveFailure, "Pointer.malloc failed"
    end

    def copy
      other = FFI::Platform::POSIX.malloc total
      other.total = total
      other.type_size = type_size
      FFI::Platform::POSIX.memcpy other, self, total
      other.send :initialize_copy, self
      other
    end

    # Indicates how many bytes the chunk of memory that is pointed to takes up.
    attr_accessor :total

    # Indicates how many bytes the type that the pointer is cast as uses.
    attr_accessor :type_size

    # Access the MemoryPointer like a C array, accessing the +which+ number
    # element in memory. The position of the element is calculate from
    # +@type_size+ and +which+. A new MemoryPointer object is returned, which
    # points to the address of the element.
    #
    # Example:
    #   ptr = MemoryPointer.new(:int, 20)
    #   new_ptr = ptr[9]
    #
    # c-equiv:
    #   int *ptr = (int*)malloc(sizeof(int) * 20);
    #   int *new_ptr;
    #   new_ptr = &ptr[9];
    #
    def [](which)
      raise ArgumentError, "unknown type size" unless @type_size
      self + (which * @type_size)
    end

    # Release the memory pointed to back to the OS.
    def free
      self.autorelease = false
      FFI::Platform::POSIX.free(self) unless null?
      #self.class.set_address self, nil
    end

    ##
    # If +val+ is true, this MemoryPointer object will call
    # free() on it's address when it is garbage collected.

    def autorelease=(val)
      Ruby.primitive :pointer_set_autorelease
      raise PrimitiveFailure, "Unable to change autorelease"
    end

  end

  class DynamicLibrary::Symbol < Pointer
    def initialize(library, ptr, name)
      @library = library
      @name = name
      self.address = ptr.address
    end

    def inspect
      "#<FFI::Library::Symbol name=#{@name} address=#{address.to_s(16)}>"
    end
  end

  class Function < Pointer
    def initialize(ret_type, arg_types, val=nil, options=nil, &block)
      if block
        if val or options
          raise ArgumentError, "specify a block or a proc/address, not both"
        end

        val = block
      end

      args = arg_types.map { |x| FFI.find_type(x) }
      ret =  FFI.find_type(ret_type)

      if val.kind_of? Pointer
        @function = FFI.generate_function(val, :func, args, ret)
        self.address = val.address
      elsif val.respond_to? :call
        @function, ptr = FFI.generate_trampoline(val, :func, args, ret)
        self.address = ptr.address
      else
        raise ArgumentError, "value wasn't a FFI::Pointer and didn't respond to call"
      end

      Rubinius.object_metaclass(self).method_table.store :call, @function, :public
    end

    attr_reader :function

    def attach(mod, name)
      unless mod.kind_of?(Module)
        raise TypeError, "mod must be a Module"
      end

      name = name.to_sym

      # Make it available as a method callable directly..
      Rubinius.object_metaclass(mod).method_table.store name, @function, :public

      # and expose it as a private method for people who
      # want to include this module.
      mod.method_table.store name, @function, :public
    end
  end
end

module stk.stk;

public import std.math : sin, cos;

/**

STK instrument abstract base class.

This class provides a common interface for
all STK instruments.

Porting portions of STK library to D.
https://github.com/thestk/stk by Perry R. Cook and Gary P. Scavone, 1995--2016.

*/

alias StkFloat = double;

enum StkFormat : uint {
    STK_SINT8 = 0x01,   /*!< -128 to +127 */
    STK_SINT16 = 0x02,  /*!< -32768 to +32767 */
    STK_SINT24 = 0x04,  /*!< Lower 3 bytes of 32-bit signed integer. */
    STK_SINT32 = 0x08,  /*!< -2147483648 to +2147483647. */
    STK_FLOAT32 = 0x10, /*!< Normalized between plus/minus 1.0. */
    STK_FLOAT64 = 0x20  /*!< Normalized between plus/minus 1.0. */
}

const StkFloat PI           = 3.14159265358979;
const StkFloat TWO_PI       = 2 * PI;
const StkFloat ONE_OVER_128 = 0.0078125;

// use StkErrorType instead of StkError::Type
enum StkErrorType {
    STATUS,
    WARNING,
    DEBUG_PRINT,
    MEMORY_ALLOCATION,
    MEMORY_ACCESS,
    FUNCTION_ARGUMENT,
    FILE_NOT_FOUND,
    FILE_UNKNOWN_FORMAT,
    FILE_ERROR,
    PROCESS_THREAD,
    PROCESS_SOCKET,
    PROCESS_SOCKET_IPADDR,
    AUDIO_SYSTEM,
    MIDI_SYSTEM,
    UNSPECIFIED
}

//! STK error handling class.
/*!
This is a fairly abstract exception handling class.  There could
be sub-classes to take care of more specific error conditions ... or
not.
*/
class StkError
{

protected:
    string message_;
    StkErrorType type_;

public:
    //! The constructor.
    this(string message, StkErrorType type = StkErrorType.UNSPECIFIED) {
        message_ = message;
        type_ = type;
    }

    //! The destructor.
    ~this() {};

    //! Prints thrown error message to stderr.
    void printMessage() { 
        //std::cerr << '\n' << message_ << "\n\n"; 
    }

    //! Returns the thrown error message type.
    StkErrorType getType() const { return type_; }

    //! Returns the thrown error message string.
    string getMessage() const { return message_; }

    //! Returns the thrown error message as a C string.
    const(char *)getMessageCString() {
        import std.string : toStringz;
        return message_.toStringz; 
    }
};

class Stk
{
    //! Static method that returns the current STK sample rate.
    static StkFloat sampleRate() {
        return srate_;
    }

    //! Static method that sets the STK sample rate.
    /*!
    The sample rate set using this method is queried by all STK
    classes that depend on its value.  It is initialized to the
    default SRATE set in Stk.h.  Many STK classes use the sample rate
    during instantiation.  Therefore, if you wish to use a rate that
    is different from the default rate, it is imperative that it be
    set \e BEFORE STK objects are instantiated.  A few classes that
    make use of the global STK sample rate are automatically notified
    when the rate changes so that internal class data can be
    appropriately updated.  However, this has not been fully
    implemented.  Specifically, classes that appropriately update
    their own data when either a setFrequency() or noteOn() function
    is called do not currently receive the automatic notification of
    rate change.  If the user wants a specific class instance to
    ignore such notifications, perhaps in a multi-rate context, the
    function Stk::ignoreSampleRateChange() should be called.
    */
    void setSampleRate( StkFloat rate ) {
        if ( rate > 0.0 && rate != srate_ ) {
            StkFloat oldRate = srate_;
            srate_ = rate;

            for ( uint i=0; i<alertList_.length; i++ )
                alertList_[i].sampleRateChanged(srate_, oldRate);
        }
    }

    //! A function to enable/disable the automatic updating of class data when the STK sample rate changes.
    /*!
    This function allows the user to enable or disable class data
    updates in response to global sample rate changes on a class by
    class basis.
    */
    void ignoreSampleRateChange( bool ignore = true ) { ignoreSampleRateChange_ = ignore; };

    //! Static method that frees memory from alertList_.
    static void  clear_alertList(){
        alertList_.length = 0;
    }

    //! Static method that returns the current rawwave path.
    static string rawwavePath() { 
        return rawwavepath_;
    }

    //! Static method that sets the STK rawwave path.
    static void setRawwavePath( string path ) {
        if (path.length)
            rawwavepath_ = path;

        // Make sure the path includes a "/"
        if ( rawwavepath_[$ - 1] != '/' )
            rawwavepath_ ~= "/";
    }

    //! Static method that byte-swaps a 16-bit data type.
    static void swap16( ubyte *ptr ) {
        ubyte val;
        // Swap 1st and 2nd bytes
        val = *(ptr);
        *(ptr) = *(ptr+1);
        *(ptr+1) = val;
    }

    //! Static method that byte-swaps a 32-bit data type.
    static void swap32( ubyte *ptr ) {
        ubyte val;

        // Swap 1st and 4th bytes
        val = *(ptr);
        *(ptr) = *(ptr+3);
        *(ptr+3) = val;

        //Swap 2nd and 3rd bytes
        ptr += 1;
        val = *(ptr);
        *(ptr) = *(ptr+1);
        *(ptr+1) = val;
    }

    //! Static method that byte-swaps a 64-bit data type.
    static void swap64( ubyte *ptr ) {
        ubyte val;

        // Swap 1st and 8th bytes
        val = *(ptr);
        *(ptr) = *(ptr+7);
        *(ptr+7) = val;

        // Swap 2nd and 7th bytes
        ptr += 1;
        val = *(ptr);
        *(ptr) = *(ptr+5);
        *(ptr+5) = val;

        // Swap 3rd and 6th bytes
        ptr += 1;
        val = *(ptr);
        *(ptr) = *(ptr+3);
        *(ptr+3) = val;

        // Swap 4th and 5th bytes
        ptr += 1;
        val = *(ptr);
        *(ptr) = *(ptr+1);
        *(ptr+1) = val;
    }

    //! Static cross-platform method to sleep for a number of milliseconds.
    static void sleep( uint milliseconds ) {
        import core.thread;
        Thread.sleep(dur!"msecs"(milliseconds));
    }

    //! Static method to check whether a value is within a specified range.
    static bool inRange( StkFloat value, StkFloat min, StkFloat max ) {
        if ( value < min ) return false;
        else if ( value > max ) return false;
        else return true;
    }

    //! Static function for error reporting and handling using c-strings.
    static void handleError( const char *message, StkErrorType type ) {
        // TODO
    }

    //! Static function for error reporting and handling using c++ strings.
    static void handleError( string message, StkErrorType type ) {
        // TODO
    }


    //! Toggle display of WARNING and STATUS messages.
    static void showWarnings( bool status ) { showWarnings_ = status; }

    //! Toggle display of error messages before throwing exceptions.
    static void printErrors( bool status ) { printErrors_ = status; }

private:
    static StkFloat srate_ = 44100;
    static string rawwavepath_ = "rawwaves/";
    static bool showWarnings_ = true;
    static bool printErrors_ = true;
    static Stk[] alertList_;

protected:

    //static std::ostringstream oStream_;
    bool ignoreSampleRateChange_ = false;

    //! Default constructor.
    this() {
    }

    //! Class destructor.
    ~this() {
    }

    //! This function should be implemented in subclasses that depend on the sample rate.
    void sampleRateChanged( StkFloat newRate, StkFloat oldRate ) {
        // This function should be reimplemented in classes that need to
        // make internal variable adjustments in response to a global sample
        // rate change.
    }

    //! Add class pointer to list for sample rate change notification.
    public static void addSampleRateAlert( Stk ptr ) {
        for ( uint i=0; i<alertList_.length; i++ )
            if ( alertList_[i] is ptr ) return;

        alertList_ ~= ptr;
    }

    //! Remove class pointer from list for sample rate change notification.
    public static void removeSampleRateAlert( Stk ptr ) {
        for ( uint i=0; i < alertList_.length; i++ ) {
            if ( alertList_[i] is ptr ) {
                for (uint j = i; j + 1 < alertList_.length; j++)
                    alertList_[j] = alertList_[j + 1];
                alertList_.length = alertList_.length - 1;
                return;
            }
        }
    }

    //! Internal function for error reporting that assumes message in \c oStream_ variable.
    void handleError( StkErrorType type ) const {
    }
}

/***************************************************/
/*! \class StkFrames
\brief An STK class to handle vectorized audio data.

This class can hold single- or multi-channel audio data.  The data
type is always StkFloat and the channel format is always
interleaved.  In an effort to maintain efficiency, no
out-of-bounds checks are performed in this class unless
_STK_DEBUG_ is defined.

Internally, the data is stored in a one-dimensional C array.  An
indexing operator is available to set and retrieve data values.
Alternately, one can use pointers to access the data, using the
index operator to get an address for a particular location in the
data:

StkFloat* ptr = &myStkFrames[0];

Note that this class can also be used as a table with interpolating
lookup.

Possible future improvements in this class could include functions
to convert to and return other data types.

by Perry R. Cook and Gary P. Scavone, 1995--2016.
*/
/***************************************************/

struct StkFrames
{
public:

    //! Overloaded constructor that initializes the frame data to the specified size with \c value.
    this(StkFloat value, uint nFrames, uint nChannels) {
        uint size_ = nFrames_ * nChannels_;

        if ( size_ > 0 ) {
            data_.length = size_;
            data_[0 .. $] = value;
        }
        dataRate_ = Stk.sampleRate();
    }

    //! The destructor.
    ~this() {
    }

    // A copy constructor.
    this( const ref StkFrames f ) {
        nFrames_ = f.nFrames_;
        nChannels_ = f.nChannels_;
        data_ = f.data_.dup;
        dataRate_ = Stk.sampleRate();
    }

    // Assignment operator that returns a reference to self.
    ref StkFrames opAssign( const ref StkFrames f ) {
        nFrames_ = f.nFrames_;
        nChannels_ = f.nChannels_;
        data_ = f.data_.dup;
        dataRate_ = Stk.sampleRate();
        return this;
    }

    //! Subscript operator that returns a reference to element \c n of self.
    /*!
    The result can be used as an lvalue. This reference is valid
    until the resize function is called or the array is destroyed. The
    index \c n must be between 0 and size less one.  No range checking
    is performed unless _STK_DEBUG_ is defined.
    */
    ref StkFloat opIndex( size_t n ) {
        assert(n < data_.length);
        return data_[n];
    }

    //! Subscript operator that returns the value at element \c n of self.
    /*!
    The index \c n must be between 0 and size less one.  No range
    checking is performed unless _STK_DEBUG_ is defined.
    */
    StkFloat opIndex( size_t n ) const {
        assert(n < data_.length);
        return data_[n];
    }

    //! Sum operator
    /*!
    The dimensions of the argument are expected to be the same as
    self.  No range checking is performed unless _STK_DEBUG_ is
    defined.
    */
    StkFrames opBinary(string op)(const ref StkFrames frames) const if (op == "+") {
        assert(nFrames_ == frames.nFrames_);
        assert(nChannels_ == frames.nChannels_);
        StkFrames sum = new StkFrames(cast(uint)nFrames_,nChannels_);
        for(uint i = 0; i < _size; i++)
            sum.data_.ptr[i] = data_.ptr[i] + frames.data_.ptr[i];
        return sum;
    }

    //! Assignment by sum operator into self.
    /*!
    The dimensions of the argument are expected to be the same as
    self.  No range checking is performed unless _STK_DEBUG_ is
    defined.
    */
    void opOpAssign(string op)(ref StkFrames f) if (op == "+") {
        assert(nFrames_ == f.nFrames_);
        assert(nChannels_ == f.nChannels_);
        for(uint i = 0; i < _size; i++)
            data_[i] += f.data_[i];
    }

    //! Assignment by product operator into self.
    /*!
    The dimensions of the argument are expected to be the same as
    self.  No range checking is performed unless _STK_DEBUG_ is
    defined.
    */
    void opOpAssign(string op)( ref StkFrames f ) if (op == "*") {
        for(uint i = 0; i < _size; i++)
            data_[i] *= f.data_[i];
    }

    //! Channel / frame subscript operator that returns a reference.
    /*!
    The result can be used as an lvalue. This reference is valid
    until the resize function is called or the array is destroyed. The
    \c frame index must be between 0 and frames() - 1.  The \c channel
    index must be between 0 and channels() - 1.  No range checking is
    performed unless _STK_DEBUG_ is defined.
    */
    ref StkFloat opCall(size_t frame, uint channel) {
        return data_[ frame * nChannels_ + channel ];
    }
    ref StkFloat opIndex(size_t frame, uint channel) {
        return data_[ frame * nChannels_ + channel ];
    }

    //! Channel / frame subscript operator that returns a value.
    /*!
    The \c frame index must be between 0 and frames() - 1.  The \c
    channel index must be between 0 and channels() - 1.  No range checking
    is performed unless _STK_DEBUG_ is defined.
    */
    StkFloat opCall( size_t frame, uint channel ) const {
        return data_[ frame * nChannels_ + channel ];
    }
    StkFloat opIndex( size_t frame, uint channel ) const {
        return data_[ frame * nChannels_ + channel ];
    }

    //! Return an interpolated value at the fractional frame index and channel.
    /*!
    This function performs linear interpolation.  The \c frame
    index must be between 0.0 and frames() - 1.  The \c channel index
    must be between 0 and channels() - 1.  No range checking is
    performed unless _STK_DEBUG_ is defined.
    */
    StkFloat interpolate( StkFloat frame, uint channel = 0 ) const {
        size_t iIndex = cast(size_t)frame;                    // integer part of index
        StkFloat output;
        StkFloat alpha = frame - cast(StkFloat)iIndex;  // fractional part of index
        iIndex = iIndex * nChannels_ + channel;
        output = data_[ iIndex ];
        if ( alpha > 0.0 ) {
            uint nindex = iIndex + nChannels_;
            if (nindex >= data_.length)
                nindex -= cast(uint)data_.length;
            output += ( alpha * ( data_[ nindex ] - output ) );
        }

        return output;
    }

    //! Returns the total number of audio samples represented by the object.
    @property uint size() const { return cast(uint)data_.length; }

    //! Returns \e true if the object size is zero and \e false otherwise.
    @property bool empty() const {
        return data_.length == 0;
    }

    //! Resize self to represent the specified number of channels and frames.
    /*!
    Changes the size of self based on the number of frames and
    channels.  No element assignment is performed.  No memory
    deallocation occurs if the new size is smaller than the previous
    size.  Further, no new memory is allocated when the new size is
    smaller or equal to a previously allocated size.
    */
    void resize( size_t nFrames, uint nChannels = 1 ) {
        uint size_ = nFrames_ * nChannels_;

        if ( size_ > 0 ) {
            data_.length = size_;
            data_[0 .. $] = 0;
        } else {
            data_ = null;
        }
        dataRate_ = Stk.sampleRate();
    }

    //! Resize self to represent the specified number of channels and frames and perform element initialization.
    /*!
    Changes the size of self based on the number of frames and
    channels, and assigns \c value to every element.  No memory
    deallocation occurs if the new size is smaller than the previous
    size.  Further, no new memory is allocated when the new size is
    smaller or equal to a previously allocated size.
    */
    void resize(size_t nFrames, uint nChannels, StkFloat value) {
        uint size_ = nFrames_ * nChannels_;

        if ( size_ > 0 ) {
            data_.length = size_;
            data_[0 .. $] = value;
        } else {
            data_ = null;
        }
        dataRate_ = Stk.sampleRate();
    }

    //! Retrieves a single channel
    /*!
    Copies the specified \c channel into \c destinationFrames's \c destinationChannel. \c destinationChannel must be between 0 and destination.channels() - 1 and
    \c channel must be between 0 and channels() - 1. destination.frames() must be >= frames().
    No range checking is performed unless _STK_DEBUG_ is defined.
    */
    ref StkFrames getChannel(uint sourceChannel, ref StkFrames destinationFrames, uint destinationChannel) const {
        uint sourceHop = nChannels_;
        uint destinationHop = destinationFrames.nChannels_;
        for (int i = sourceChannel, j = destinationChannel; i < nFrames_ * nChannels_; i+=sourceHop,j+=destinationHop) {
            destinationFrames[j] = data_[i];
        }
        return destinationFrames;
    }

    //! Sets a single channel
    /*!
    Copies the \c sourceChannel of \c sourceFrames into the \c channel of self.
    SourceFrames.frames() must be equal to frames().
    No range checking is performed unless _STK_DEBUG_ is defined.
    */
    void setChannel(uint destinationChannel, const ref StkFrames sourceFrames, uint sourceChannel) {
        uint sourceHop = sourceFrames.nChannels_;
        uint destinationHop = nChannels_;
        for (int i  = destinationChannel,j = sourceChannel ; i < nFrames_ * nChannels_; i+=destinationHop,j+=sourceHop) {
            data_[i] = sourceFrames[j];
        }
    }

    //! Return the number of channels represented by the data.
    @property uint channels() const { return nChannels_; }

    //! Return the number of sample frames represented by the data.
    @property uint frames() const { return cast(uint)nFrames_; };

    //! Set the sample rate associated with the StkFrames data.
    /*!
    By default, this value is set equal to the current STK sample
    rate at the time of instantiation.
    */
    void setDataRate( StkFloat rate ) { dataRate_ = rate; }

    //! Return the sample rate associated with the StkFrames data.
    /*!
    By default, this value is set equal to the current STK sample
    rate at the time of instantiation.
    */
    @property StkFloat dataRate() const { return dataRate_; }

    void fill(StkFloat value) {
        foreach(ref f; data_)
            f = value;
    }

private:
    StkFloat[] data_;
    StkFloat dataRate_;
    uint nFrames_;
    uint nChannels_;
}

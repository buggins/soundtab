module stk.sinewave;

const uint TABLE_SIZE = 2048;

import stk.generator;

/***************************************************/
/*! \class SineWave
\brief STK sinusoid oscillator class.

This class computes and saves a static sine "table" that can be
shared by multiple instances.  It has an interface similar to the
WaveLoop class but inherits from the Generator class.  Output
values are computed using linear interpolation.

The "table" length, set in SineWave.h, is 2048 samples by default.

by Perry R. Cook and Gary P. Scavone, 1995--2016.
*/
/***************************************************/

class SineWave : Generator
{
public:
    //! Default constructor.
    this() {
        if ( table_.empty() ) {
            table_.resize( TABLE_SIZE + 1, 1 );
            StkFloat temp = 1.0 / TABLE_SIZE;
            for ( uint i=0; i<=TABLE_SIZE; i++ )
                table_[i] = sin( TWO_PI * i * temp );
        }
        Stk.addSampleRateAlert( this );
    }

    //! Class destructor.
    ~this() {
        Stk.removeSampleRateAlert( this );
    }

    //! Clear output and reset time pointer to zero.
    void reset() {
        time_ = 0.0;
        lastFrame_[0] = 0;
    }

    //! Set the data read rate in samples.  The rate can be negative.
    /*!
    If the rate value is negative, the data is read in reverse order.
    */
    void setRate( StkFloat rate ) { rate_ = rate; };

    //! Set the data interpolation rate based on a looping frequency.
    /*!
    This function determines the interpolation rate based on the file
    size and the current Stk::sampleRate.  The \e frequency value
    corresponds to file cycles per second.  The frequency can be
    negative, in which case the loop is read in reverse order.
    */
    void setFrequency( StkFloat frequency ) {
        this.setRate( TABLE_SIZE * frequency / Stk.sampleRate() );
    }

    //! Increment the read pointer by \e time in samples, modulo the table size.
    void addTime( StkFloat time ) {
        // Add an absolute time in samples.
        time_ += time;
    }

    //! Increment the read pointer by a normalized \e phase value.
    /*!
    This function increments the read pointer by a normalized phase
    value, such that \e phase = 1.0 corresponds to a 360 degree phase
    shift.  Positive or negative values are possible.
    */
    void addPhase( StkFloat phase ) {
        // Add a time in cycles (one cycle = TABLE_SIZE).
        time_ += TABLE_SIZE * phase;
    }

    //! Add a normalized phase offset to the read pointer.
    /*!
    A \e phaseOffset = 1.0 corresponds to a 360 degree phase
    offset.  Positive or negative values are possible.
    */
    void addPhaseOffset( StkFloat phaseOffset ) {
        // Add a phase offset relative to any previous offset value.
        time_ += ( phaseOffset - phaseOffset_ ) * TABLE_SIZE;
        phaseOffset_ = phaseOffset;
    }

    //! Return the last computed output value.
    StkFloat lastOut() const { return lastFrame_[0]; };

    //! Compute and return one output sample.
    StkFloat tick() {
        // Check limits of time address ... if necessary, recalculate modulo
        // TABLE_SIZE.
        while ( time_ < 0.0 )
            time_ += TABLE_SIZE;
        while ( time_ >= TABLE_SIZE )
            time_ -= TABLE_SIZE;

        iIndex_ = cast (uint) time_;
        alpha_ = time_ - iIndex_;
        StkFloat tmp = table_[ iIndex_ ];
        tmp += ( alpha_ * ( table_[ iIndex_ + 1 ] - tmp ) );

        // Increment time, which can be negative.
        time_ += rate_;

        lastFrame_[0] = tmp;
        return lastFrame_[0];
    }

    //! Fill a channel of the StkFrames object with computed outputs.
    /*!
    The \c channel argument must be less than the number of
    channels in the StkFrames argument (the first channel is specified
    by 0).  However, range checking is only performed if _STK_DEBUG_
    is defined during compilation, in which case an out-of-range value
    will trigger an StkError exception.
    */
    ref StkFrames tick( ref StkFrames frames, uint channel = 0 ) {
        StkFloat *samples = &frames[channel];
        StkFloat tmp = 0.0;

        uint hop = frames.channels();
        for ( uint i=0; i < frames.frames(); i++, samples += hop ) {

            // Check limits of time address ... if necessary, recalculate modulo
            // TABLE_SIZE.
            while ( time_ < 0.0 )
                time_ += TABLE_SIZE;
            while ( time_ >= TABLE_SIZE )
                time_ -= TABLE_SIZE;

            iIndex_ = cast(uint) time_;
            alpha_ = time_ - iIndex_;
            tmp = table_[ iIndex_ ];
            tmp += ( alpha_ * ( table_[ iIndex_ + 1 ] - tmp ) );
            *samples = tmp;

            // Increment time, which can be negative.
            time_ += rate_;
        }

        lastFrame_[0] = tmp;
        return frames;
    }

protected:

    override void sampleRateChanged( StkFloat newRate, StkFloat oldRate ) {
        if ( !ignoreSampleRateChange_ )
            this.setRate( oldRate * rate_ / newRate );
    }

    static __gshared StkFrames table_;
    StkFloat time_ = 0;
    StkFloat rate_ = 1;
    StkFloat phaseOffset_ = 0;
    uint iIndex_;
    StkFloat alpha_;

}

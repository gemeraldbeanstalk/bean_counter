# BeanCounter

[![Build Status](https://secure.travis-ci.org/gemeraldbeanstalk/bean_counter.png)](http://travis-ci.org/gemeraldbeanstalk/bean_counter)
[![Dependency Status](https://gemnasium.com/gemeraldbeanstalk/bean_counter.png)](https://gemnasium.com/gemeraldbeanstalk/bean_counter)
[![Coverage Status](https://coveralls.io/repos/gemeraldbeanstalk/bean_counter/badge.png?branch=master)](https://coveralls.io/r/gemeraldbeanstalk/bean_counter)
[![Code Climate](https://codeclimate.com/github/gemeraldbeanstalk/bean_counter.png)](https://codeclimate.com/github/gemeraldbeanstalk/bean_counter)

BeanCounter provides additional TestUnit/MiniTest assertions and/or RSpec matchers for testing Ruby code that relies on
[Beaneater](https://github.com/beanstalkd/beaneater) and [Beanstalkd](https://github.com/kr/beanstalkd).

##### TestUnit/MiniTest Assertions
For TestUnit/MiniTest, BeanCounter provides 6 assertions/refutations
for use in your tests:
  - ```assert_enqueued/refute_enqueued``` - Searches all jobs in the beanstalkd
  pool for jobs with attributes matching the keys/values of the Hash given
  - ```assert_enqueues/refute_enqueues``` - Searches only those jobs in the
  beanstalkd pool enqueued during the execution of the provided block for jobs
  with attributes matching the keys/values of the Hash given
  - ```assert_tube/refute_tube``` - Searches all tubes in the beanstalkd pool
  for a tube with attributes matching the keys/values of a given Hash

BeanCounter also provides a helper, ```BeanCounter.reset!``` to reset a given tube or
the entire beanstalkd pool by deleting the appropriate jobs.

##### RSpec Matchers
For RSpec, BeanCounter provides 2 equivalent should/should_not matchers for use in your specs:
  - ```have_enqueued``` - Searches for jobs in the beanstalkd
  pool with attributes matching the keys/values of the Hash given.
  If called on a block only inspects jobs enqueued during the execution of
  the block. Otherwise, inspects all jobs.
  - ```have_tube``` - Searches all tubes in the beanstalkd pool
  for a tube with attributes matching the keys/values of a given Hash

BeanCounter also provides a helper, ```BeanCounter.reset!``` to reset a given tube or
the entire beanstalkd pool by deleting the appropriate jobs.

## Installation

Add this line to your application's Gemfile:

    gem 'bean_counter'

And then execute:

    $ bundle

Or install it without bundler:

    $ gem install bean_counter

## Test Framework Configuration
#### TestUnit/MiniTest
In order to use BeanCounter in your tests you'll need to require and configure
it in your test_helper:
```ruby
# To make the assertions available to all test cases you can require one of the
# following in test/test_helper.rb:

# For TestUnit, adds assertions to Test::Unit::TestCase and any derived classes:
require 'bean_counter/test_unit'

# For MiniTest, adds assertions to MiniTest::Unit::TestCase and any derived classes:
require 'bean_counter/mini_test'


# To maintain greater control over where the assertions are available, require
# bean_counter/test_assertions directly then include BeanCounter::TestAssertions
# in any test classes where you want to make use of the assertions:

# test/test_helper.rb
require 'bean_counter/test_assertions'

# test/beaneater_test.rb
require 'test_helper'

# For TestUnit:
class BeaneaterTest < Test::Unit::TestCase
  include BeanCounter::TestAssertions

  # assertions will be available to all tests in this class
end

# Or for MiniTest:
class BeaneaterTest < MiniTest::Unit::TestCase
  include BeanCounter::TestAssertions

  # assertions will be available to all tests in this class
end
```

#### RSpec
In order to use BeanCounter in your specs you'll need to require and configure
it in your spec_helper:
```ruby
# To make the BeanCounter matchers available to all specs, require
# bean_counter/spec in spec/spec_helper.rb:
require 'bean_counter/spec'


# To maintain more control over where the matchers are available, require
# bean_counter/spec_matchers directly and include BeanCounter::SpecMatchers in
# any spec where you want to use the matchers:

# spec/spec_helper.rb
require 'bean_counter/spec_matchers'

# Then include BeanCounter::SpecMatchers in any test class that needs access to the
# matchers:

# spec/beaneater_client_spec.rb
require 'spec_helper'

describe BeaneaterClient do
  include BeanCounter::SpecMatchers

  # matchers will be available to all test cases inside this block
end
```

## General Configuration
Beyond the configuration required to utilize BeanCounter with your test
framework, BeanCounter may also require other test framework agnostic
configuration to work properly or as desired.

#####BeanCounter.beanstalkd_url
```BeanCounter.beanstalkd_url``` allows you to directly provide a string or an
Array of strings that will be used by BeanCounter when communicating with the
beanstalkd pool. By default, BeanCounter will try to intelligently determine
the location of beanstalkd servers by checking for configuration in a few
different places, though in some cases special configuration may be required.

First, and of higest precedence, BeanCounter will check
```ENV['BEANSTALKD_URL']``` for a comma separated list of beanstalkd
servers. If no evironment variable is found, any value provided for
```BeanCounter.beanstalkd_url``` will be used to connect to the the beanstalkd pool.
Finally, if no environment variable is found and no value has been provided for
BeanCounter.beanstalkd_url, BeanCounter will try to use any configuration
provided to Beaneater. If no beanstalkd_url can be determined, a Runtime error
will be raised.

Beanstalkd urls can be provided in any of the variety of formats shown below:
```
$ BEANSTALKD_URL='127.0.0.1,beanstalk://localhost:11300,localhost:11301' rake test
BeanCounter.beanstalkd_url
  #=> ['127.0.0.1', 'beanstalk://localhost:11300', 'localhost:11301']

BeanCounter.beanstalkd_url = 'beanstalk://localhost'
BeanCounter.beanstalkd_url
  #=> 'beanstalk://localhost'

BeanCounter.beanstalkd_url = ['127.0.0.1', 'beanstalk://localhost:11300', 'localhost:11301']
BeanCounter.beanstalkd_url
  #=> ['127.0.0.1', 'beanstalk://localhost:11300', 'localhost:11301']
```

#####BeanCounter.strategy
```BeanCounter.strategy``` allows you to choose and configure the strategy
BeanCounter uses for accessing and interacting with the beanstalkd pool. At
present, there is only a single strategy available, but at least one other is
in the works.

The strategy currently available, BeanCounter::Strategy::StalkClimber, utilizes
[StalkClimber](https://github.com/gemeraldbeanstalk/stalk_climber.git) to
navigate the beanstalkd pool. The job traversal method employed by StalkClimber
suffers from some inefficiencies that come with trying to sequential access a
queue, but overall it is a powerful strategy that supports multiple servers and
offers solid performance given the design of beanstalkd.

## Usage
Whether you are using the TestUnit/MiniTest or RSpec matchers, the usage is the
same, the only difference is the invocation.

Each assertion/matcher takes a Hash of options that will be used to find
matching jobs. Each key in the options Hash is a String or a Symbol that
identifies an attribute of a job that the corresponding Hash value should be
compared against. All attribute comparisons are performed using the triple-equal
(===) operator/method of the given value.

#####assert_enqueued/have_enqueued
The attributes available on a job for comparison are: ```age```, ```body```,
```buries```, ```connection```, ```delay```, ```id```, ```kicks```, ```pri```,
```releases```, ```reserves```, ```state```, ```time-left```, ```timeouts```,
```ttr```, and ```tube```.

To assert or set the expectation that a job with the body of 'foo'
should have been enqueued on the default tube you could use the following:
```
  # TestUnit/MiniTest
  assert_enqueued(:tube => 'default', :body => 'foo')

  # You could also use a Regexp if you prefer
  # RSpec
  should have_enqueued(:tube => 'default', :body => /foo/)
```

#####assert_enqueues/have_enqueued
The assert_enqueues assertion and the have_enqueued matcher also support a
block form that will only check jobs enqueued during the execution of the given
block for matches. For example, if you wanted to assert or set the expectation
that a particular method caused a job to be enqueued to the exports tube in the
ready state, you could use something like the following:
```
  # TestUnit/MiniTest
  assert_enqueues(:tube => 'exports', :state => 'ready') do
    method_that_should_enqueue_a_job
  end

  # The form is a little different in RSpec:
  proc do
    method_that_should_enqueue_a_job
  end.should have_enqueued(:tube => 'exports', :state => 'ready')
```

The refutations/negative matches work the same way:
```
  # TestUnit/MiniTest
  refute_enqueues(:tube => 'exports', :state => 'ready') do
    method_that_should_not_enqueue_a_job
  end

  # RSpec:
  proc do
    method_that_should_enqueue_a_job
  end.should_not have_enqueued(:tube => 'exports', :state => 'ready')
```

The options Hash for enqueued/enqueues assertions/matchers may additionally
include a count key ('count' or :count) that can be used to verify that a
particular number of matching jobs are found.

If no count option is provided, the assertion/match succeeds if any job is found
that matches all of the options given. If no jobs are found that match the
options given, the assertion fails.

If a count option is provided the assertion/matcher only succeeds if the
triple-equal (===) operator/method of the value of the provided count evaluates
to true when given the total number of matching jobs. Otherwise the assertion
fails. The use of === allows for more advanced comparisons using Procs, Ranges,
Regexps, etc.
```
  # TestUnit/MiniTest
  assert_enqueues(:tube => 'default', :body => 'foo', :count => 1) do
    method_that_should_enqueue_exactly_one_job
  end

  # You could also use a Range if you prefer
  # RSpec
  proc do
    method_that_should_enqueue_between_1_and_3_jobs
  end.should have_enqueued(:tube => 'default', :body => /foo/, :count => 1..3)
```

A count key can also be used with the refutations/negative matches, but tends
to be better stated as an assertion/positive match with a count.

#####assert_tube/have_tube
Similar to the other assertions/matchers, assert_tube and have_tube take a Hash
of options that will be used to find matching tubes. Each key in the options
Hash is a String or a Symbol that identifies an attribute of a tube that the
corresponding Hash value should be compared against. All attribute comparisons
are performed using the triple-equal (===) operator/method of the given value.

The attributes available on a tube for matching are: ```cmd-delete```,
```cmd-pause-tube```, ```current-jobs-buried```, ```current-jobs-delayed```,
```current-jobs-ready```, ```current-jobs-reserved```,
```current-jobs-urgent```, ```current-using```, ```current-waiting```,
```current-watching```, ```name```, ```pause```, ```pause-time-left```,
and ```total-jobs```.

For example to assert that no connections are waiting on the default tube
something like the following could be used:
```
  # TestUnit/MiniTest
  assert_tube(:name => 'default', 'current-waiting' => 0)

  # RSpec
  should have_tube(:name => 'default', 'current-waiting' => 0)
```

Similarly one could use refute_tube or the negative matcher for have_tube to
verify that the exports tube is paused:
```
  # TestUnit/MiniTest
  refute_tube(:name => 'exports', :pause => 0)

  #RSpec
  should_not have_tube(:name => 'exports', :pause => 0)
```

For more detailed explanations and more examples make sure to check out the
docs, expectations, and respective tests:  
[docs](http://rubydoc.info/gems/bean_counter/0.0.1/frames)  
[enqueued_expectation](https://github.com/gemeraldbeanstalk/bean_counter/tree/master/lib/bean_counter/enqueued_expectation.rb)  
[tube_expectation](https://github.com/gemeraldbeanstalk/bean_counter/tree/master/lib/bean_counter/tube_expectation.rb)  
[test_assertions](https://github.com/gemeraldbeanstalk/bean_counter/tree/master/lib/bean_counter/test_assertions.rb)  
[spec_matchers](https://github.com/gemeraldbeanstalk/bean_counter/tree/master/lib/bean_counter/spec_matchers.rb)  
[test_assertions_test](https://github.com/gemeraldbeanstalk/bean_counter/tree/master/test/unit/test_assertions_test.rb)  
[spec_spec](https://github.com/gemeraldbeanstalk/bean_counter/tree/master/spec/spec_spec.rb)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

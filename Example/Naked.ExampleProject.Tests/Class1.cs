using NUnit.Framework;

namespace Naked.ExampleProject.Tests
{
    [TestFixture]
    public class MultiplicationTests
    {
        [Test]
        public void can_multiple_two_numbers_correctly()
        {
            int result = 3*3;

            Assert.AreEqual(9, result);
        }
    }
}

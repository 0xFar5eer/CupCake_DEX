//Truncates n first and last characters in string. Especially useful for displaying shortened versions of wallet adresses
export const truncateStr = (str, n = 6) => {
  if (!str) return "";
  return str.length > n
    ? str.substr(0, n - 1) + "..." + str.substr(str.length - n, str.length - 1)
    : str;
};

//Checks if x is float or integer
export const isFloat = (x) => {
  // check if the passed value is a number
  if ((typeof x == "number" && !isNaN(x)) || !isNaN(Number(x))) {
    // check if it is integer
    if (Number.isInteger(Number(x))) {
      //console.log(`${x} is integer.`);
      return false;
    } else {
      //console.log(`${x} is a float value.`);
      return true;
    }
  } else {
    //console.log(`${x} is not a number`);
    return false;
  }
};

//Useful for controlled delays in async functions
export const delay = (ms) => new Promise((res) => setTimeout(res, ms));

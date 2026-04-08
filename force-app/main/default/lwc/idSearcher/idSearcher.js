import { LightningElement, track } from 'lwc';
import processIDSearch from '@salesforce/apex/IDValidationController.processIDSearch';

export default class IdSearcher extends LightningElement {
    @track idNumber = '';
    @track results;
    @track errorMessage = '';
    @track isValid = false;
    @track isLoading = false;
    @track isButtonDisabled = true;
    @track isBornOnHoliday = false;
    @track holidayName = '';

    handleInputChange(event) {
        this.idNumber = event.target.value;
        
        // This resets results and validates on each keystroke
        this.results = null;
        this.isValid = false; 
        this.isButtonDisabled = true;
        this.isBornOnHoliday = false;

        // This checks if the field is empty annd clears everything
        if (!this.idNumber) {
            this.errorMessage = '';
        } 
        // This checks if the user is typing and the ID number is not yet valid
        else if (this.idNumber.length < 13) {
            this.errorMessage = 'Please enter a valid ID number.';
            
            // THis checks for letters being typed 
            if (!/^\d+$/.test(this.idNumber)) {
                this.errorMessage = 'ID numbers contain digits only.';
            }
        } 
        // This runs final checks exactly 13 digits 
        else if (this.idNumber.length === 13) {
            if (this.luhnCheck(this.idNumber)) {
                this.isValid = true;
                this.isButtonDisabled = false;
                this.errorMessage = ''; // Clear error because it's now valid
            } else {
                this.errorMessage = 'Please enter a valid ID number.';
                this.isValid = false;
            }
        }
        // Over 13 digits. This is not particularly necessary because of field length
        else {
            this.errorMessage = 'Too many digits. A valid ID number has 13 digits.';
        }
    }
    // This Luhn check is used to check validity of ID number
    luhnCheck(id) {
        let sum = 0;
        let shouldDouble = false;
        for (let i = id.length - 1; i >= 0; i--) {
            let digit = parseInt(id.charAt(i), 10);
            if (shouldDouble) {
                digit *= 2;
                if (digit > 9) digit -= 9;
            }
            sum += digit;
            shouldDouble = !shouldDouble;
        }
        return (sum % 10 === 0);
    }

    async handleSearch() {
        this.isLoading = true;
        this.errorMessage = '';
        this.results = null; 

        try {
            const data = await processIDSearch({ idNumber: this.idNumber });
            this.results = data;
            if (this.results && this.results.holidays) {
                this.checkBirthHoliday();
            } else if (!this.results) {
                this.errorMessage = 'No record found for this ID.';
            }
        } catch (error) {
            this.errorMessage = 'System error: ' + (error.body ? error.body.message : error.message);
        } finally {
            this.isLoading = false;
        }
    }
    // This checks for a holiday on the birth date
    checkBirthHoliday() {
        if (!this.idNumber || !this.results.holidays) return;
        const idDatePart = this.idNumber.substring(0, 6);
        const match = this.results.holidays.find(h => {
            const formattedHoliday = h.date.iso.replace(/-/g, '').substring(2);
            return formattedHoliday === idDatePart;
        });

        if (match) {
            this.isBornOnHoliday = true;
            this.holidayName = match.name;
        } else {
            this.isBornOnHoliday = false;
        }
    }
}
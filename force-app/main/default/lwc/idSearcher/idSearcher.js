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

    /**
     * Handles real-time validation as the user types
     */
    handleInputChange(event) {
        this.idNumber = event.target.value;
        
        // Reset state on every keystroke
        this.results = null;
        this.isValid = false; 
        this.isButtonDisabled = true;
        this.isBornOnHoliday = false;
        this.holidayName = '';

        if (!this.idNumber) {
            this.errorMessage = '';
        } 
        else if (this.idNumber.length < 13) {
            this.errorMessage = 'Please enter a valid ID number.';
            
            // Check for non-numeric characters
            if (!/^\d+$/.test(this.idNumber)) {
                this.errorMessage = 'ID numbers contain digits only.';
            }
        } 
        else if (this.idNumber.length === 13) {
            if (this.luhnCheck(this.idNumber)) {
                this.isValid = true;
                this.isButtonDisabled = false;
                this.errorMessage = ''; 
            } else {
                this.errorMessage = 'Invalid ID number (failed checksum).';
                this.isValid = false;
            }
        }
        else {
            this.errorMessage = 'Too many digits. A valid ID number has 13 digits.';
        }
    }

    /**
     * Standard Luhn Algorithm for South African ID validation
     */
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

    /**
     * Calls Apex to process data and save history
     */
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
            // Catches AuraHandledExceptions from Apex
            this.errorMessage = 'System error: ' + (error.body ? error.body.message : error.message);
        } finally {
            this.isLoading = false;
        }
    }

    /**
     * Compares the DOB from the ID (YYMMDD) against the simplified holiday list
     */
    checkBirthHoliday() {
        if (!this.idNumber || !this.results.holidays) return;

        // Extract YYMMDD from the ID number
        const idDatePart = this.idNumber.substring(0, 6);

        // 'h' is now a flat object { iso: 'YYYY-MM-DD', name: '...' } from our cleaned Apex
        const match = this.results.holidays.find(h => {
            if (h.iso) {
                // Convert YYYY-MM-DD to YYMMDD
                const formattedHoliday = h.iso.replace(/-/g, '').substring(2, 8);
                return formattedHoliday === idDatePart;
            }
            return false;
        });

        if (match) {
            this.isBornOnHoliday = true;
            this.holidayName = match.name;
        } else {
            this.isBornOnHoliday = false;
            this.holidayName = '';
        }
    }
}
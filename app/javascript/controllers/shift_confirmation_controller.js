import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { 
    existingReservations: Array
  }

  confirmSubmit(event) {
    const conflicts = this.checkConflicts(event);
    
    if (conflicts.length > 0) {
      const message = this.buildConflictMessage(conflicts);
      alert(message);
      event.preventDefault();
      event.stopPropagation();
      return false;
    }
    // No conflicts, allow form submission
    return true;
  }

  checkConflicts(event) {
    const conflicts = [];
    const formData = new FormData(event.target);
    
    this.existingReservationsValue.forEach(reservation => {
      // ISO日付形式をローカル日付として扱う
      const [year, month, day] = reservation.date.split('-').map(Number);
      const date = new Date(year, month - 1, day);
      const dayNumber = date.getDate();
      
      const isHolidayField = `shift_data[${dayNumber}][is_holiday]`;
      const startTimeField = `shift_data[${dayNumber}][start_time]`;
      const endTimeField = `shift_data[${dayNumber}][end_time]`;
      
      const isHoliday = formData.get(isHolidayField) === "1";
      const startTime = formData.get(startTimeField);
      const endTime = formData.get(endTimeField);
      
      // 休業日に設定しようとしている場合
      if (isHoliday) {
        conflicts.push({
          type: 'holiday',
          date: reservation.date,
          dayNumber: dayNumber,
          customerName: reservation.customer_name,
          time: `${reservation.start_time}〜${reservation.end_time}`,
          startTimeMinutes: this.timeToMinutes(reservation.start_time)
        });
      }
      // 営業時間外になる場合
      else if (startTime && endTime) {
        const resStart = this.timeToMinutes(reservation.start_time);
        const resEnd = this.timeToMinutes(reservation.end_time);
        const newStart = this.timeToMinutes(startTime);
        const newEnd = this.timeToMinutes(endTime);
        
        if (resStart < newStart || resEnd > newEnd) {
          conflicts.push({
            type: 'out_of_hours',
            date: reservation.date,
            dayNumber: dayNumber,
            customerName: reservation.customer_name,
            reservationTime: `${reservation.start_time}〜${reservation.end_time}`,
            newHours: `${startTime}〜${endTime}`,
            startTimeMinutes: resStart
          });
        }
      }
    });
    
    // 日付順、時間順にソート
    conflicts.sort((a, b) => {
      // まず日付でソート
      if (a.dayNumber !== b.dayNumber) {
        return a.dayNumber - b.dayNumber;
      }
      // 同じ日なら時間でソート
      return a.startTimeMinutes - b.startTimeMinutes;
    });
    
    return conflicts;
  }

  buildConflictMessage(conflicts) {
    let message = "以下の予約があるため、設定できません。\n\n";
    
    const holidayConflicts = conflicts.filter(c => c.type === 'holiday');
    const hourConflicts = conflicts.filter(c => c.type === 'out_of_hours');
    
    if (holidayConflicts.length > 0) {
      message += "【休業日に設定しようとしている日に予約があります】\n";
      holidayConflicts.forEach(conflict => {
        const [year, month, day] = conflict.date.split('-').map(Number);
        const date = new Date(year, month - 1, day);
        const dateStr = `${date.getMonth() + 1}月${date.getDate()}日`;
        message += `・${dateStr} ${conflict.time} - ${conflict.customerName}様\n`;
      });
      message += "\n";
    }
    
    if (hourConflicts.length > 0) {
      message += "【営業時間外になってしまう予約があります】\n";
      hourConflicts.forEach(conflict => {
        const [year, month, day] = conflict.date.split('-').map(Number);
        const date = new Date(year, month - 1, day);
        const dateStr = `${date.getMonth() + 1}月${date.getDate()}日`;
        message += `・${dateStr} 予約：${conflict.reservationTime} - ${conflict.customerName}様\n`;
        message += `  （新しい営業時間：${conflict.newHours}）\n`;
      });
      message += "\n";
    }
    
    message += "予約の変更または設定の見直しをお願いします。";
    
    return message;
  }

  timeToMinutes(timeStr) {
    const [hours, minutes] = timeStr.split(':').map(Number);
    return hours * 60 + minutes;
  }
}